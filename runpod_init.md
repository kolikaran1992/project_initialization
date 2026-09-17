# RunPod + Qwen3-Coder-30B + Opencode Setup

Last verified: 2026-09-17

## Goal

Deploy a RunPod Serverless vLLM endpoint that:

- Works with OpenAI-compatible APIs
- Works with Opencode
- Supports tool calling / MCP
- Supports Claude-Code-style agent workflows
- Returns proper `message.content`
- Returns proper `tool_calls`

---

# Model

```text
Qwen/qwen3-coder-30b-a3b-instruct-fp8
```

---

# Critical Lessons Learned

## DO NOT USE

```text
TOOL_CALL_PARSER=llama3_json
```

This causes:

```text
Llama3JsonToolParser could not locate the bot token '<|python_tag|>'
```

because Qwen3-Coder is not a Llama model. :contentReference[oaicite:0]{index=0}

---

## DO USE

```text
ENABLE_AUTO_TOOL_CHOICE=true
TOOL_CALL_PARSER=qwen3_xml
```

Qwen3-Coder has a dedicated parser in vLLM. :contentReference[oaicite:1]{index=1}

---

# Environment Variables

These were the working values.

Only the critical values are listed here.

```text
MODEL_NAME=qwen/qwen3-coder-30b-a3b-instruct-fp8

TOKENIZER_MODE=auto
TRUST_REMOTE_CODE=true

DTYPE=half
KV_CACHE_DTYPE=fp8

MAX_MODEL_LEN=32768

GPU_MEMORY_UTILIZATION=0.9

ENABLE_AUTO_TOOL_CHOICE=true
TOOL_CALL_PARSER=qwen3_xml
REASONING_PARSER=qwen3

OPENAI_SERVED_MODEL_NAME_OVERRIDE=qwen3-moe

ENFORCE_EAGER=true

RAW_OPENAI_OUTPUT=true
OPENAI_RESPONSE_ROLE=assistant
```

Everything else can stay at RunPod defaults unless a future deployment proves otherwise.

---

# OpenAI-Compatible Endpoint

Base URL:

```text
https://api.runpod.ai/v2/<ENDPOINT_ID>/openai/v1
```

RunPod vLLM endpoints expose OpenAI-compatible APIs through this path. :contentReference[oaicite:2]{index=2}

Example:

```text
https://api.runpod.ai/v2/8szmxm7ebe076k/openai/v1
```

---

# Verify Model Registration

```bash
curl https://api.runpod.ai/v2/<ENDPOINT_ID>/openai/v1/models \
  -H "Authorization: Bearer $RUNPOD_API_KEY"
```

Expected:

```json
{
  "data": [
    {
      "id": "qwen3-moe"
    }
  ]
}
```

---

# Verify Chat Completions

```bash
curl https://api.runpod.ai/v2/<ENDPOINT_ID>/openai/v1/chat/completions \
  -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model":"qwen3-moe",
    "messages":[
      {
        "role":"user",
        "content":"Hello"
      }
    ]
  }'
```

Expected:

```json
{
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "Hello!"
      }
    }
  ]
}
```

Important:

```json
"content": "..."
```

must be populated.

If:

```json
"content": null
```

appears, something is wrong.

---

# Verify Tool Calling

Use:

```json
{
  "model": "qwen3-moe",
  "messages": [
    {
      "role": "user",
      "content": "What's the weather in Delhi?"
    }
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get weather",
        "parameters": {
          "type": "object",
          "properties": {
            "city": {
              "type": "string"
            }
          },
          "required": ["city"]
        }
      }
    }
  ],
  "tool_choice": "auto"
}
```

Expected:

```json
{
  "finish_reason": "tool_calls",
  "message": {
    "tool_calls": [
      {
        "function": {
          "name": "get_weather",
          "arguments": "{\"city\":\"Delhi\"}"
        }
      }
    ]
  }
}
```

This confirms MCP-compatible tool calling.

---

# Opencode Configuration

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "runpod-qwen": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "RunPod Qwen3 Coder",
      "options": {
        "baseURL": "https://api.runpod.ai/v2/<ENDPOINT_ID>/openai/v1",
        "apiKey": "{env:RUNPOD_API_KEY}"
      },
      "models": {
        "qwen3-moe": {
          "name": "Qwen3 Coder 30B MoE",
          "limit": {
            "context": 32768,
            "output": 4096
          }
        }
      }
    }
  },
  "model": "runpod-qwen/qwen3-moe",
  "small_model": "runpod-qwen/qwen3-moe"
}
```

Environment variable:

```bash
export RUNPOD_API_KEY=your_key_here
```

---

# Cold Start Notes

Observed:

```text
Startup: ~4–6 minutes
```

This is normal for a 30B model.

A deployment after changing environment variables may take even longer because:

- Container starts
- vLLM initializes
- Model loads
- KV cache builds
- Health checks complete

Expect:

```text
2–6 minutes
```

for normal cold starts.

---

# Troubleshooting

## Error

```text
Llama3JsonToolParser could not locate the bot token '<|python_tag|>'
```

Fix:

```text
REMOVE:
TOOL_CALL_PARSER=llama3_json

ADD:
TOOL_CALL_PARSER=qwen3_xml
REASONING_PARSER=qwen3
```

---

## Error

```json
{
  "status": 500,
  "detail": "internal server error"
}
```

Check:

- TOOL_CALL_PARSER
- REASONING_PARSER
- Worker logs

Most likely a parser mismatch.

---

## Success Criteria

A deployment is considered healthy when:

✅ `/models` works

✅ `/chat/completions` works

✅ `message.content` is populated

✅ Tool calling returns `finish_reason=tool_calls`

✅ Opencode can invoke MCP tools

At that point the endpoint is production-ready for Opencode.
