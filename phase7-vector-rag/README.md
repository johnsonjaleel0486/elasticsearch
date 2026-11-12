# Phase 7: Vector and hybrid search for AI (RAG)

**Goal:** run the retrieval layer of an AI assistant on the secure cluster from Phase 2, and keep it as locked down as the rest of the platform.

## Plan
1. **Vector mapping:** index with a `dense_vector` field (dims match the embedding model, `similarity: cosine`, HNSW), plus normal text/keyword fields for metadata.
2. **Embeddings:** generate embeddings for a small document set (runbooks, README files, public docs) with a local model (e.g. sentence-transformers via Python, or Ollama), bulk load them.
3. **Search three ways and compare:**
   - Keyword only (BM25 `match`)
   - Vector only (`knn`)
   - Hybrid: BM25 + kNN combined with Reciprocal Rank Fusion (RRF)
4. **RAG Q&A:** small Python script: question, retrieve top chunks with hybrid search, pass them to an LLM, answer with source citations.
5. **Document-level security:** two roles that see different document sets (e.g. `team: ops` vs `team: dev`); prove the same question returns different context per user, so the AI can only use what that user is allowed to see.
6. **Ops view:** vector index size vs plain text, kNN latency, heap usage, and what that means for capacity planning (quantization, more data nodes).

## Interview angle
"AI teams build the app; I run the retrieval platform underneath it: secured with TLS and least privilege, document-level security so the assistant only retrieves what the user is cleared to see, ILM and snapshots like any other index, and capacity planned for vector memory."

Status: Planned (after Phases 3-6).
