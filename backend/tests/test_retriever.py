from knowledge_base.retriever import MentalHealthRetriever

SAMPLE_DOCS = [
    {"id": "G-1", "domain": "General", "title": "Breathing Exercise",
     "type": "technique", "text": "Deep breathing helps reduce anxiety and stress."},
    {"id": "A-1", "domain": "Anxiety & Worry", "title": "Understanding Anxiety",
     "type": "psychoeducation", "text": "Anxiety is a natural response to perceived threats."},
    {"id": "C-1", "domain": "Crisis", "title": "Crisis Support",
     "type": "technique", "text": "Call a crisis hotline if you feel unsafe or suicidal."},
]

retriever = MentalHealthRetriever(SAMPLE_DOCS)


def test_tokenize_lowercases():
    tokens = retriever._tokenize("Hello World")
    assert tokens == ["hello", "world"]


def test_tokenize_splits_whitespace():
    tokens = retriever._tokenize("deep breathing exercise")
    assert len(tokens) == 3


def test_retrieve_returns_results():
    results = retriever.retrieve("anxiety breathing", dsm5_flags=[], top_k=2)
    assert isinstance(results, list)


def test_retrieve_excludes_crisis_by_default():
    results = retriever.retrieve("crisis suicidal", dsm5_flags=[], top_k=5)
    domains = [r["domain"] for r in results]
    assert "Crisis" not in domains


def test_retrieve_with_dsm5_flags():
    results = retriever.retrieve("anxiety", dsm5_flags=["Anxiety & Worry"], top_k=2)
    assert isinstance(results, list)
