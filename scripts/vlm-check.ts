// مساعد VLM — يقرأ لقطة شاشة ويجيب عن سؤال (لأغراض QA فقط).
// الاستخدام: bun scripts/vlm-check.ts <image> <question>
import ZAI from 'z-ai-web-dev-sdk';
import fs from 'fs';

async function main() {
  const [image, question] = process.argv.slice(2);
  if (!image || !question) {
    console.error('Usage: bun scripts/vlm-check.ts <image> <question>');
    process.exit(1);
  }
  const zai = await ZAI.create();
  const base64 = fs.readFileSync(image).toString('base64');
  const res = await zai.chat.completions.createVision({
    messages: [
      {
        role: 'user',
        content: [
          { type: 'text', text: question },
          { type: 'image_url', image_url: { url: `data:image/png;base64,${base64}` } },
        ],
      },
    ],
    thinking: { type: 'disabled' },
  });
  console.log(res.choices[0]?.message?.content ?? '(no content)');
}

main().catch((e) => {
  console.error('VLM error:', e.message);
  process.exit(1);
});
