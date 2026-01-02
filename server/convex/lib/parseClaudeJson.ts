/**
 * Claude API configuration constants.
 */
export const CLAUDE_MODEL = "claude-sonnet-4-20250514";
export const CLAUDE_MAX_TOKENS = 8192;

/**
 * Standard response shape from the Claude API.
 */
export interface ClaudeResponse {
  content?: Array<{ type: string; text: string }>;
}

/**
 * Parse JSON from Claude's response, handling markdown code blocks.
 * @param text - The raw text response from Claude
 * @returns The parsed JSON object
 * @throws Error if parsing fails
 */
export function parseClaudeJson<T = unknown>(text: string): T {
  // Strip markdown code blocks if present
  let jsonText = text;
  if (jsonText.includes("```")) {
    jsonText = jsonText.replace(/```json\s*/g, "").replace(/```\s*/g, "");
  }

  const jsonMatch = jsonText.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    throw new Error("No JSON found in response");
  }

  try {
    return JSON.parse(jsonMatch[0]) as T;
  } catch (parseError) {
    const errorMsg =
      parseError instanceof Error ? parseError.message : "Unknown parse error";
    throw new Error(
      `Failed to parse JSON (${errorMsg}): ${text.substring(0, 200)}...`
    );
  }
}
