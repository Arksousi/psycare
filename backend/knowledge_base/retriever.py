from typing import List, Dict, Optional
from rank_bm25 import BM25Okapi


class MentalHealthRetriever:
    MIN_SCORE = 0.05  # low threshold so vague messages still get help

    def __init__(self, documents: List[Dict]):
        self._docs = documents
        self._global_bm25 = self._build_bm25(documents)

    def _tokenize(self, text: str) -> List[str]:
        return text.lower().split()

    def _build_bm25(self, docs: List[Dict]) -> BM25Okapi:
        corpus = [self._tokenize(d["text"] + " " + d["title"]) for d in docs]
        return BM25Okapi(corpus)

    def retrieve(
        self,
        query: str,
        dsm5_flags: List[str],
        top_k: int = 2,
        include_types: Optional[List[str]] = None,
    ) -> List[Dict]:
        tokenized_query = self._tokenize(query)

        # 1. Build candidate pool
        if include_types:
            candidates = [d for d in self._docs if d["type"] in include_types]
        elif dsm5_flags:
            # Always include General domain + flagged domains
            relevant_domains = set(dsm5_flags) | {"General"}
            candidates = [d for d in self._docs if d["domain"] in relevant_domains]
        else:
            candidates = [d for d in self._docs if d["domain"] != "Crisis"]

        if not candidates:
            return []

        # 2. Score candidates
        bm25 = self._build_bm25(candidates)
        scores = bm25.get_scores(tokenized_query)

        ranked = sorted(zip(scores, candidates), key=lambda x: x[0], reverse=True)
        results = [doc for score, doc in ranked[:top_k] if score > self.MIN_SCORE]

        # 3. Fallback: if filtered search found nothing, use global (excluding Crisis)
        if not results and dsm5_flags and not include_types:
            non_crisis = [d for d in self._docs if d["domain"] != "Crisis"]
            global_bm25 = self._build_bm25(non_crisis)
            global_scores = global_bm25.get_scores(tokenized_query)
            global_ranked = sorted(
                zip(global_scores, non_crisis), key=lambda x: x[0], reverse=True
            )
            results = [doc for score, doc in global_ranked[:top_k] if score > self.MIN_SCORE]

        # 4. Last resort fallback: return General chunks so AI always has something actionable
        if not results and not include_types:
            general = [d for d in self._docs if d["domain"] == "General"]
            results = general[:top_k]

        return results
