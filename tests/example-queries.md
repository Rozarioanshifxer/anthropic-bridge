# Example Test Queries for Smart Router

This file contains example queries for testing smart-router with different AI models using Claude CLI.

## Basic Functionality Tests

### Health Check
```bash
claude --settings config/glm.json -p "Hello, respond with 'OK' if you are working"
```

### Simple Math
```bash
claude --settings config/glm.json -p "Calculate: 123 + 456"
```

### Text Generation
```bash
claude --settings config/glm.json -p "Write a haiku about programming"
```

## Code-Related Tests

### Code Generation - Python
```bash
claude --settings config/deepseek-v3.1-terminus.json -p "Write a Python function to check if a number is prime. Include docstring and type hints."
```

### Code Generation - JavaScript
```bash
claude --settings config/qwen3-coder-plus.json -p "Create a JavaScript async function to fetch data from an API with error handling"
```

### Code Review
```bash
claude --settings config/glm.json -p "Review this code and suggest improvements:
function calc(a,b){
  return a+b
}
"
```

### Code Explanation
```bash
claude --settings config/deepseek-v3.1-terminus.json -p "Explain what this regex does: ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
```

### Bug Finding
```bash
claude --settings config/qwen3-coder-flash.json -p "Find the bug in this code:
def divide(a, b):
    return a / b

result = divide(10, 0)
"
```

## Language Support Tests

### Chinese (GLM, Kimi)
```bash
claude --settings config/glm.json -p "用中文解释什么是人工智能"
```

### Multilingual
```bash
claude --settings config/gemini-2.5-pro.json -p "Translate 'Hello, how are you?' to French, Spanish, and German"
```

## Complex Reasoning Tests

### Problem Solving
```bash
claude --settings config/gpt-5-pro.json -p "A farmer has 17 sheep. All but 9 die. How many sheep are left?"
```

### Logic Puzzle
```bash
claude --settings config/claude-sonnet-4.5.json -p "Three people are in a room: Alice, Bob, and Charlie. Alice is taller than Bob. Charlie is shorter than Bob. Who is the tallest?"
```

### Chain of Thought
```bash
claude --settings config/glm.json -p "Think step by step: If a train travels at 60 mph and needs to cover 180 miles, how long will the journey take?"
```

## Creative Tasks

### Story Writing
```bash
claude --settings config/gpt-5-codex.json -p "Write a short story (3 paragraphs) about a robot learning to cook"
```

### Poetry
```bash
claude --settings config/claude-sonnet-4.5.json -p "Compose a sonnet about the beauty of mathematics"
```

### Brainstorming
```bash
claude --settings config/gemini-2.5-pro.json -p "Generate 5 creative names for a new coffee shop that focuses on sustainable practices"
```

## Technical Documentation Tests

### API Documentation
```bash
claude --settings config/deepseek-v3.1-terminus-exacto.json -p "Create OpenAPI documentation for a REST endpoint that creates user accounts"
```

### README Generation
```bash
claude --settings config/qwen3-coder-plus.json -p "Write a README.md for a project that converts markdown to PDF"
```

### Architecture Explanation
```bash
claude --settings config/gpt-5-pro.json -p "Explain the microservices architecture pattern with pros and cons"
```

## Model Comparison Tests

Run the same query across different models to compare responses:

### Test Query 1: Code Quality
```bash
# With GLM
claude --settings config/glm.json -p "What are the SOLID principles in software engineering?"

# With Deepseek
claude --settings config/deepseek-v3.1-terminus.json -p "What are the SOLID principles in software engineering?"

# With GPT-5
claude --settings config/gpt-5-pro.json -p "What are the SOLID principles in software engineering?"
```

### Test Query 2: Practical Implementation
```bash
# With Qwen3 Coder Flash
claude --settings config/qwen3-coder-flash.json -p "Implement a LRU cache in Python"

# With Qwen3 Coder Plus
claude --settings config/qwen3-coder-plus.json -p "Implement a LRU cache in Python"

# With Deepseek
claude --settings config/deepseek-v3.1-terminus-exacto.json -p "Implement a LRU cache in Python"
```

## Edge Cases and Error Handling

### Very Long Input
```bash
claude --settings config/glm.json -p "Summarize: $(cat /path/to/long/document.txt)"
```

### Special Characters
```bash
claude --settings config/glm.json -p "Explain the difference between == and === in JavaScript. Use code examples with <, >, &, and \""
```

### Empty/Minimal Input
```bash
claude --settings config/glm.json -p "?"
```

### Multi-line Input
```bash
claude --settings config/glm.json -p "Analyze this multi-line text:
Line 1: Introduction
Line 2: Details
Line 3: Conclusion
What is the structure?"
```

## Performance Tests

### Response Time Test
```bash
time claude --settings config/glm.json -p "Quick response test"
```

### Complex Query Performance
```bash
time claude --settings config/deepseek-v3.1-terminus-exacto.json -p "Generate a complete REST API with authentication, CRUD operations, and error handling in Node.js with Express"
```

## Batch Testing Script

Create a file `tests/run-batch-tests.sh`:

```bash
#!/bin/bash

# Array of configurations to test
configs=(
  "config/glm.json"
  "config/deepseek-v3.1-terminus.json"
  "config/qwen3-coder-plus.json"
  "config/gpt-5-pro.json"
)

# Array of test queries
queries=(
  "Hello, respond with OK"
  "What is 2+2?"
  "Write a Python hello world function"
)

# Run tests
for config in "${configs[@]}"; do
  echo "Testing with: $config"
  for query in "${queries[@]}"; do
    echo "Query: $query"
    claude --settings "$config" -p "$query"
    echo "---"
  done
  echo ""
done
```

## Usage

```bash
# Make script executable
chmod +x tests/run-batch-tests.sh

# Run batch tests
./tests/run-batch-tests.sh

# Run single test
claude --settings config/glm.json -p "Your test query here"

# Run with timing
time claude --settings config/glm.json -p "Your test query here"

# Save output for comparison
claude --settings config/glm.json -p "Test query" > results/glm-result.txt
claude --settings config/deepseek.json -p "Test query" > results/deepseek-result.txt
diff results/glm-result.txt results/deepseek-result.txt
```

## Test Documentation

After running tests, document:

1. **Model response quality**: Rate the response (1-5)
2. **Response time**: Use `time` command
3. **Accuracy**: Is the answer correct?
4. **Formatting**: Is output well-formatted?
5. **Edge cases**: How does it handle unusual inputs?

Example test log:

```
Test: Basic Math
Model: GLM-4.6-Exacto
Query: "What is 123 + 456?"
Response: "579"
Time: 1.2s
Quality: 5/5
Notes: Correct answer, fast response
```

## Tips

1. **Start with simple queries** before complex ones
2. **Compare multiple models** for the same query
3. **Document unexpected behaviors** for future reference
4. **Test edge cases** to ensure robustness
5. **Monitor service logs** while testing
6. **Keep queries version controlled** for regression testing
7. **Create model-specific query sets** based on strengths
