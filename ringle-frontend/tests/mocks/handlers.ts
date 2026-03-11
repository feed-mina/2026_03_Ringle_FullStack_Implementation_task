import { http, HttpResponse } from "msw";

export const handlers = [
  // 멤버십 현황 조회
  http.get("/api/v1/user_memberships/current", () => {
    return HttpResponse.json({
      data: {
        id: 1,
        membership: {
          id: 1,
          name: "프리미엄",
          can_learn: true,
          can_converse: true,
          can_analyze: true,
          duration_days: 30,
          price_cents: 49900,
        },
        started_at: new Date().toISOString(),
        expires_at: new Date(
          Date.now() + 30 * 24 * 60 * 60 * 1000
        ).toISOString(),
        status: "active",
        granted_by: "purchase",
      },
    });
  }),

  // STT: 오디오 → 텍스트
  http.post("/api/v1/ai/stt", () => {
    return HttpResponse.json({
      data: { text: "Hello, I would like to practice English." },
    });
  }),

  // Chat: 텍스트 → AI 응답 (SSE Streaming)
  http.post("/api/v1/ai/chat", () => {
    const encoder = new TextEncoder();
    const chunks = ["Hello! ", "How can ", "I help you ", "today?"];

    const stream = new ReadableStream({
      start(controller) {
        let i = 0;
        const tick = () => {
          if (i < chunks.length) {
            controller.enqueue(
              encoder.encode(
                `data: ${JSON.stringify({ content: chunks[i] })}\n\n`
              )
            );
            i++;
            setTimeout(tick, 50);
          } else {
            controller.enqueue(encoder.encode("data: [DONE]\n\n"));
            controller.close();
          }
        };
        tick();
      },
    });

    return new HttpResponse(stream, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
      },
    });
  }),

  // TTS: 텍스트 → 오디오
  http.post("/api/v1/ai/tts", () => {
    return new HttpResponse(new ArrayBuffer(8), {
      headers: { "Content-Type": "audio/mpeg" },
    });
  }),

  // 결제 Mock
  http.post("/api/v1/payments", () => {
    return HttpResponse.json(
      { data: { success: true, transaction_id: "mock_txn_001" } },
      { status: 201 }
    );
  }),
];
