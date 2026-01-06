//
//  GeminiPrompts.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

enum GeminiPrompts {

    static let flyerBasic: String = """
    You are extracting factual exhibition information from a Japanese exhibition poster image.

    Respond ONLY in valid JSON.
    Do NOT include explanations, markdown, or extra text.

    --------------------------------
    GENERAL RULES
    --------------------------------
    - Extract ONLY factual information explicitly written on the poster.
    - Do NOT infer, interpret, or normalize meanings beyond the instructions below.
    - Do NOT include exhibition descriptions, artist explanations, curatorial texts, or event descriptions.
    - Do NOT translate. Preserve original language as written on the poster.
    - Keep proper nouns in original script.
    - If information is not clearly stated, use null or empty arrays.
    - Dates must be converted to YYYY-MM-DD.
    - Times must be converted to 24-hour HH:mm format.

    --------------------------------
    OUTPUT FORMAT
    --------------------------------

    {
      "title": string,
      "venue": string,
      "venue_poi": string,

      "period": {
        "start_date": "YYYY-MM-DD",
        "end_date": "YYYY-MM-DD",
        "period_text": string
      },

      "regular_schedule": {
        "open_time": "HH:mm",
        "close_time": "HH:mm",
        "last_entry_time": "HH:mm" | null,
        "closed_weekdays": [
          "monday" | "tuesday" | "wednesday" | "thursday" | "friday" | "saturday" | "sunday"
        ],
        "holiday_handling": "NONE" | "OPEN_ON_HOLIDAY" | "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY"
      },

      "exceptions": {
        "closed_dates": ["YYYY-MM-DD"],
        "open_dates": ["YYYY-MM-DD"],
        "special_openings": [
          {
            "date": "YYYY-MM-DD"
                  | "EVERY_MONDAY" | "EVERY_TUESDAY" | "EVERY_WEDNESDAY"
                  | "EVERY_THURSDAY" | "EVERY_FRIDAY"
                  | "EVERY_SATURDAY" | "EVERY_SUNDAY",
            "open_time": "HH:mm",
            "close_time": "HH:mm",
            "last_entry_time": "HH:mm" | null,
            "note": string | null
          }
        ]
      },

      "admission": {
        "is_free": boolean,
        "fees": [
          {
            "category":
              "adult"
              | "university_student"
              | "high_school_student"
              | "junior_high_student"
              | "elementary_student"
              | "preschool"
              | "senior"
              | "free"
              | "other",
            "label": string,
            "price_yen": number | null,
            "note": string | null
          }
        ]
      },

      "reservation": {
        "required": boolean,
        "note": string | null
      },

      "url": string | null
    }

    --------------------------------
    DETAILED INSTRUCTIONS
    --------------------------------

    ### period
    - Extract the exhibition period exactly as written.
    - Convert to start_date and end_date when possible.

    ### regular_schedule
    - Use this ONLY for the default opening rule.
    - If multiple default rules exist (e.g. Fridays only), use special_openings instead.
    - If no closed weekday is specified, return an empty array.
    - If holiday handling is not clearly stated, set holiday_handling to "NONE".

    ### exceptions
    - Use ONLY when explicitly stated.
    - closed_dates: specific dates when the exhibition is closed.
    - open_dates: specific dates when the exhibition is open despite normal closure.
    - special_openings: only when opening hours differ from the regular schedule.
    - If a specific date is listed as open/closed without hours, put it in open_dates/closed_dates (NOT special_openings).
    - Do NOT include exhibition events (e.g., gallery talks, lectures, workshops) as special_openings.
    - Do NOT include closed weekdays or holiday rules inside special_openings.
    - If a line describes an event time without open/close hours, ignore it.

    ### admission (IMPORTANT)
    - Extract ONLY admission fee information.
    - Set is_free to true ONLY if the exhibition is explicitly stated as free.
    - For each fee:
      - category must be chosen from the predefined enum.
      - label must preserve the original wording on the poster
        (e.g. "中高生", "小学生以下", "高校生・大学生").
    - If a category covers multiple age groups (e.g. "中高生"):
      - Choose the closest representative category
        (e.g. "high_school_student").
    - If the fee is free, set price_yen to 0 and explain briefly in note if needed.
    - price_yen = null MUST NEVER mean free.
    - Do NOT merge or split categories beyond what is written.
    - Do NOT interpret user attributes.

    ### reservation
    - Set required to true ONLY if advance reservation is explicitly required.
    - If reservation is partial or conditional, set required to true and explain briefly in note.

    --------------------------------
    IMPORTANT PROHIBITIONS
    --------------------------------
    - Do NOT infer missing prices or age rules.
    - Do NOT invent categories.
    - Do NOT normalize categories into broader concepts (e.g. do NOT convert to "student").
    - Do NOT output explanations.

    If information cannot be confidently extracted, use null or empty arrays.
    """

    
}
