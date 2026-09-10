# GPT (ChatGPT) — obsidian-workflow integration

ใช้ obsidian-workflow กับ ChatGPT (web หรือ API) โดย paste prompts จาก folder นี้

## วิธีใช้

### Web (chatgpt.com)
1. เริ่ม new chat — paste `prompts/system.md` เป็น Custom Instructions
2. เริ่มงานด้วย verb เช่น "ow-plan: เพิ่ม search feature"
3. ChatGPT จะอ่าน `prompts/router.md` mapping → route ไป `.ow/commands/ow-<verb>.md`

### API
```bash
curl https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "system", "content": "'"$(cat gpt/prompts/system.md)"'"},
      {"role": "user", "content": "ow-plan: '"$TASK"'"}
    ]
  }'
```

## Verb mapping (เหมือน Codex AGENTS.md)

ChatGPT อ่าน `gpt/prompts/router.md` แล้ว load `.ow/commands/<verb>.md` ผ่าน file attachment หรือ paste

## ข้อจำกัด

- ChatGPT ไม่ได้มี file system access ในตัว (เว้นแต่ใช้ Code Interpreter)
- ต้องใช้ uploads / canvas / Code Interpreter เพื่อ read/write vault files
- Best workflow: paste current vault state เป็น context, ทำงาน 1 turn, นำผลลัพธ์มา manual apply
