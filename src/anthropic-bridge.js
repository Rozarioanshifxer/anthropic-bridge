#!/usr/bin/env node
/**
 * Anthropic Bridge - Anthropic to OpenAI Translator for OpenRouter
 *
 * Features:
 * - Single endpoint on localhost:3000
 * - Format translation only: Anthropic ↔ OpenAI
 * - Routes all requests to OpenRouter
 * - Model passed via Claude settings file (e.g., glm.json)
 */

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

// Configuration
const PORT = 3000;
const LOG_FILE = '/tmp/anthropic-bridge.log';

// OpenRouter configuration
const OPENROUTER = {
  name: 'OpenRouter',
  endpoint: 'openrouter.ai',
  port: 443,
  path: '/api/v1/chat/completions'
};

// Log function
function log(message) {
  const timestamp = new Date().toISOString();
  const logMsg = `[${timestamp}] ${message}\n`;
  fs.appendFileSync(LOG_FILE, logMsg);
  console.log(message);
}

// Load environment variables
function loadEnv() {
  // Check if OPENROUTER_API_KEY is already in environment (from Docker)
  if (process.env.OPENROUTER_API_KEY) {
    log(`✓ Using OPENROUTER_API_KEY from environment`);
    return;
  }

  // Fallback: try to load from .env file
  const envFile = path.join(__dirname, '../../.env');
  log(`Loading environment from: ${envFile}`);
  if (fs.existsSync(envFile)) {
    const env = fs.readFileSync(envFile, 'utf8');
    let keysLoaded = 0;
    env.split('\n').forEach(line => {
      const match = line.match(/^([^=]+)=(.*)$/);
      if (match && match[1] && match[2]) {
        process.env[match[1]] = match[2];
        if (match[1].includes('API_KEY')) {
          keysLoaded++;
        }
      }
    });
    log(`✓ Loaded ${keysLoaded} API keys from ${envFile}`);
  } else {
    log(`✗ Environment file not found: ${envFile}`);
    log(`  Please create ${envFile} with OPENROUTER_API_KEY`);
  }
}

// Convert Anthropic format to OpenAI format
function anthropicToOpenAI(anthropicBody) {
  const messages = anthropicBody.messages || [];

  // Add system message if present
  const openAIMessages = [];
  if (anthropicBody.system) {
    openAIMessages.push({
      role: 'system',
      content: anthropicBody.system
    });
  }

  // Convert messages
  messages.forEach(msg => {
    openAIMessages.push({
      role: msg.role,
      content: msg.content
    });
  });

  return {
    model: anthropicBody.model,
    messages: openAIMessages,
    max_tokens: anthropicBody.max_tokens || 4096,
    temperature: anthropicBody.temperature || 1,
    stream: anthropicBody.stream || false
  };
}

// Convert OpenAI format back to Anthropic format
function openAIToAnthropic(openAIResponse, originalModel) {
  const choice = openAIResponse.choices?.[0];
  if (!choice) {
    return {
      id: openAIResponse.id || 'unknown',
      type: 'message',
      role: 'assistant',
      content: [{ type: 'text', text: 'Error: No response from provider' }],
      model: originalModel,
      stop_reason: 'error'
    };
  }

  return {
    id: openAIResponse.id,
    type: 'message',
    role: 'assistant',
    content: [{
      type: 'text',
      text: choice.message?.content || ''
    }],
    model: originalModel,
    stop_reason: choice.finish_reason === 'stop' ? 'end_turn' : choice.finish_reason,
    usage: {
      input_tokens: openAIResponse.usage?.prompt_tokens || 0,
      output_tokens: openAIResponse.usage?.completion_tokens || 0
    }
  };
}

// Forward request to OpenRouter
function forwardToOpenRouter(body, incomingApiKey, callback) {
  const modelName = body.model;
  log(`→ Forwarding to OpenRouter: ${modelName}`);

  // Convert Anthropic to OpenAI format
  const openAIRequest = anthropicToOpenAI(body);
  const postData = JSON.stringify(openAIRequest);

  // Prepare headers
  const headers = {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData),
    'Authorization': `Bearer ${process.env.OPENROUTER_API_KEY}`,
    'http-referer': 'https://claude-code.local',
    'x-title': 'Claude Code Smart Router'
  };

  log(`  Using OpenRouter API key from environment`);

  const options = {
    hostname: OPENROUTER.endpoint,
    port: OPENROUTER.port,
    path: OPENROUTER.path,
    method: 'POST',
    headers: headers
  };

  const req = https.request(options, (res) => {
    let data = '';

    res.on('data', (chunk) => {
      data += chunk;
    });

    res.on('end', () => {
      try {
        const response = JSON.parse(data);

        // Debug: log full response if no choices
        if (!response.choices || response.choices.length === 0) {
          log(`  ⚠️  No choices in response. Full response: ${JSON.stringify(response).substring(0, 500)}`);
        }

        // Convert OpenAI response back to Anthropic format
        const anthropicResponse = openAIToAnthropic(response, modelName);

        log(`✓ Response received from OpenRouter`);
        callback(null, anthropicResponse);
      } catch (error) {
        log(`✗ Parse error: ${error.message}`);
        callback(error);
      }
    });
  });

  req.on('error', (error) => {
    log(`✗ Request error: ${error.message}`);
    callback(error);
  });

  req.write(postData);
  req.end();
}

// Handle HTTP request
function handleRequest(req, res) {
  // Parse URL to get pathname without query parameters
  const url = new URL(req.url, `http://${req.headers.host || 'localhost:3000'}`);
  const pathname = url.pathname;

  // Log ALL incoming requests
  log(`📥 ${req.method} ${pathname} from ${req.headers['user-agent'] || 'unknown'}`);

  // Health check endpoint
  if (req.method === 'GET' && pathname === '/health') {
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({
      status: 'healthy',
      service: 'Smart Router',
      provider: 'OpenRouter',
      mode: 'anthropic-to-openai-translator'
    }));
    return;
  }

  // Status endpoint
  if (req.method === 'GET' && pathname === '/status') {
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({
      service: 'Smart Router',
      provider: 'OpenRouter',
      endpoint: `https://${OPENROUTER.endpoint}${OPENROUTER.path}`,
      mode: 'format-translator-only'
    }));
    return;
  }

  // Models list endpoint
  if (req.method === 'GET' && pathname === '/v1/models') {
    const timestamp = new Date().toISOString();
    log(`📋 Models list requested at ${timestamp}`);
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({
      object: 'list',
      data: [
        {
          id: 'openrouter/default',
          object: 'model',
          created: 1735948800,
          owned_by: 'openrouter',
          context_window: 200000
        }
      ]
    }));
    return;
  }

  // Only handle POST /v1/messages
  if (req.method !== 'POST' || pathname !== '/v1/messages') {
    log(`❌ 404 Not Found: ${req.method} ${pathname} (expected: POST /v1/messages)`);
    res.writeHead(404, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({error: 'Not found'}));
    return;
  }

  // Extract API key from request headers
  const incomingApiKey = req.headers['x-api-key'] || req.headers['authorization']?.replace(/^Bearer /i, '');

  let body = '';
  req.on('data', (chunk) => {
    body += chunk;
  });

  req.on('end', () => {
    try {
      const requestBody = JSON.parse(body);
      const modelName = requestBody.model;

      log(`✓ Model from settings: ${modelName}`);
      log(`✓ Translating: Anthropic format → OpenAI format → OpenRouter`);

      forwardToOpenRouter(requestBody, incomingApiKey, (error, response) => {
        if (error) {
          res.writeHead(500, {'Content-Type': 'application/json'});
          res.end(JSON.stringify({
            error: {
              type: 'api_error',
              message: error.message
            }
          }));
          return;
        }

        res.writeHead(200, {'Content-Type': 'application/json'});
        res.end(JSON.stringify(response));
      });
    } catch (error) {
      log(`✗ Request parse error: ${error.message}`);
      res.writeHead(400, {'Content-Type': 'application/json'});
      res.end(JSON.stringify({
        error: {
          type: 'invalid_request_error',
          message: error.message
        }
      }));
    }
  });
}

// Initialize router
function start() {
  log('🚀 Smart Router starting...');
  log('Mode: Anthropic → OpenAI Translator for OpenRouter');

  // Load environment
  loadEnv();

  // Check OpenRouter API key
  if (!process.env.OPENROUTER_API_KEY) {
    log('⚠️  WARNING: OPENROUTER_API_KEY not found in environment');
    log('   Please set it in .env');
  }

  // Start HTTP server
  const server = http.createServer(handleRequest);

  server.listen(PORT, '0.0.0.0', () => {
    log(`✓ Smart Router listening on http://0.0.0.0:${PORT}`);
    log(`  Service: Anthropic → OpenAI Translator`);
    log(`  Target: OpenRouter (${OPENROUTER.endpoint})`);
    log(`  Model: Passed via Claude settings file`);
  });

  // Handle shutdown
  process.on('SIGTERM', () => {
    log('⚠ Received SIGTERM, shutting down...');
    server.close(() => {
      log('✓ Server closed');
      process.exit(0);
    });
  });

  process.on('SIGINT', () => {
    log('⚠ Received SIGINT, shutting down...');
    server.close(() => {
      log('✓ Server closed');
      process.exit(0);
    });
  });
}

// Start the router
start();
