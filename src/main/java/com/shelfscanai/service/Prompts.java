package com.shelfscanai.service;

public class Prompts {

    public static final String EXTRACT_PROMPT =
            "SYSTEM: Output ONLY valid JSON matching the schema. No markdown, no extra text.\n" +
                    "TASK: From the book cover image, extract:\n" +
                    "- title (string or null)\n" +
                    "- author (string or null)\n" +
                    "If a volume/number is visible (e.g. Vol. 3, #3, Tome 3), include it inside the title string.\n" +
                    "If multiple candidates exist, pick the most likely.\n" +
                    "Return confidence in [0,1] and notes explaining uncertainty.\n" +
                    "Do not invent author if not visible; use null.\n";

    public static String enrichPrompt(String title, String author) {
        return "SYSTEM: Output ONLY valid JSON matching the schema. No markdown, no extra text.\n" +
                "TASK:\n" +
                "- author: if CONTEXT author is missing/unknown, infer the most likely real author from the title.\n" +
                "- description: write the BOOK PLOT/SYNOPSIS (trama), not the cover description.\n" +
                "  5-8 sentences, neutral tone, avoid major spoilers (no ending reveals).\n" +
                "- tags: 5-10 short tags (1-3 words each), lowercase, no duplicates.\n" +
                "- confidence: [0,1] about correctness of book identification.\n" +
                "\n" +
                "IMPORTANT RULES:\n" +
                "1) DO NOT describe the image/cover (no colors, no people on the cover, no layout, no fonts).\n" +
                "2) Use the title (and author if present) to recall the actual book synopsis.\n" +
                "3) If the title is ambiguous (multiple books share it) or uncertain, keep the synopsis generic and set confidence <= 0.4.\n" +
                "4) If you cannot infer the author reliably, return author as \"unknown\" and set confidence <= 0.4.\n" +
                "\n" +
                "CONTEXT:\n" +
                "title: \"" + title + "\"\n" +
                "author: \"" + author + "\"\n";
    }
}