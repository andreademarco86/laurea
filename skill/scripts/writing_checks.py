"""Writing checks shared by the examiner's report and paper review checkers."""
import re

# Filler and AI-sounding phrasing (style warnings)
SLOP = [r"\bdelv\w*", r"\bshowcas\w*", r"\bleverag(e|es|ed|ing)\b", r"\bcomprehensive\b", r"\bholistic\b",
        r"\bmeticulous\w*", r"\bseamless\w*", r"\bpivotal\b", r"\bcrucial role\b", r"\ba testament to\b",
        r"\bin the realm of\b", r"\blandscape\b", r"\btapestry\b", r"\bunderscor\w*", r"\bit is worth noting\b",
        r"\bit is important to note\b", r"\boverall,? the (?:dissertation|paper)\b", r"\bnot only\b.{0,80}\bbut also\b",
        r"\bcutting[- ]edge\b", r"\bstate[- ]of[- ]the[- ]art\b(?![^.]*\b(table|fig|p\.))", r"^\s*[-*]?\s*(?:\d+\.\s+)?(Furthermore|Moreover|Additionally),",
        r"!(?!\[)", r"\bClaude\b", r"\bAnthropic\b", r"\b(?:AI|LLM)[- ]generated\b", r"\blanguage model\b", r"\bas an AI\b",
        r"\bnavigat\w* the\b", r"\bintricate\b", r"\bnuanced\b", r"\bmultifaceted\b"]

# Corrections and changes are for the reader: plain and direct
VAGUE = re.compile(r"\b(consider|may wish|might want|could benefit|would benefit|could perhaps|enhanc\w*|robustness|rigou?r)\b", re.I)


def filler(body):
    """{phrase: count} of filler phrasing in `body`."""
    hits = {}
    for pat in SLOP:
        for m in re.finditer(pat, body, re.I | re.M):
            key = m.group(0).strip()[:30].lower()
            hits[key] = hits.get(key, 0) + 1
    return hits


def long_sentences(body, limit=40):
    return [s for s in re.split(r"(?<=[.?])\s+", re.sub(r"\s+", " ", body)) if len(s.split()) > limit]


def process_mentions(body, words):
    """Mentions of a process behind the document, e.g. 'the panel' or 'the reviewers'."""
    pattern = r"\b(?:the|our|this|other) (?:" + "|".join(words) + r")\b"
    return sorted({m.group(0).lower() for m in re.finditer(pattern, body, re.I)})
