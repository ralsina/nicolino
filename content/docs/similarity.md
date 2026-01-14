---
title: Similarity Feature
---

The **similarity feature** provides automatic "related posts" functionality using MinHash signatures to estimate content similarity between posts.

## Overview

This feature implements a lightweight document similarity system that:

- Calculates MinHash signatures for each post during build time
- Stores signatures in the key-value store for fast lookup
- Finds related posts based on Jaccard similarity estimation
- Returns the top 5 most similar posts for each article

## Enabling the Feature

The similarity feature is **disabled by default**. To enable it, add `similarity` to the features list in your `conf.yml`:

```yaml
features:
  - assets
  - base16
  - posts
  - similarity  # Add this line
  - taxonomies
```

## How It Works

### MinHash Signatures

MinHash is a probabilistic data structure that estimates Jaccard similarity between sets. The implementation uses:

1. **Tokenization**: Converts post text into lowercase words, removing punctuation and short words (< 3 characters)
2. **Shingling**: Creates 3-word n-grams (shingles) from the tokenized text
3. **Hashing**: Applies 128 different hash functions to each shingle
4. **Signature**: Stores the minimum hash value for each function

The resulting signature is a compact 128-element array that approximates the content.

### Jaccard Similarity

Jaccard similarity measures the overlap between two sets:

```
J(A,B) = |A ∩ B| / |A ∪ B|
```

MinHash allows us to estimate this efficiently by comparing signature elements:

- Count how many of the 128 hash values match between two signatures
- Divide by 128 to get the similarity score (0.0 to 1.0)

### Performance

The MinHash approach reduces similarity computation from **O(n²)** to **O(n)**:

- **Traditional**: Compare every post with every other post
- **MinHash**: Each post has a fixed-size signature, comparison is O(1)

For a site with 1000 posts:

- Traditional: ~500,000 comparisons
- MinHash: ~5,000 comparisons (only for candidates)

## Using in Templates

The feature adds a `related_posts` field to each post that templates can access:

```jinja
{% if post.related_posts %}
<section class="related-posts">
  <h2>Related Posts</h2>
  <ul>
  {% for related in post.related_posts %}
    <li>
      <a href="{{ related.link }}">{{ related.title }}</a>
      (similarity: {{ "%.1f"|format(related.score * 100) }}%)
    </li>
  {% endfor %}
  </ul>
</section>
{% endif %}
```

Each related post contains:
- `link`: The URL path to the post
- `title`: The post title
- `score`: Similarity score from 0.0 to 1.0 (higher = more similar)

## How Similarity is Calculated

The similarity score represents the estimated Jaccard similarity between two posts:

- **1.0**: Posts have nearly identical content
- **0.5**: Posts share about half their content
- **0.0**: Posts have no content overlap

The calculation considers:
- Post title (weighted equally with content)
- Post body text (after markdown conversion)
- Ignores HTML tags, markdown syntax, and very common words

## Configuration

You can adjust the similarity algorithm by modifying these values in `src/similarity.cr`:

```crystal
# Number of hash functions (higher = more accurate, slower)
Similarity.num_permutations = 128  # default

# N-gram size for shingling (higher = more context, less matches)
Similarity.ngram_size = 3  # default
```

## Technical Details

### Storage

Signatures are stored in the build system's key-value store:
- `similarity/signatures/{lang}/{post_link}.json` - Individual post signatures
- `similarity/index/{lang}` - Index of all post links

Each signature is approximately 512 bytes (128 × 4-byte integers).

### Build Process

1. During build, similarity tasks are created for each post
2. Tasks run in parallel (if `--parallel` is enabled)
3. Signatures are calculated and stored in the kv store
4. An index is built with all post links
5. When rendering posts, `related_posts()` queries the kv store for similar posts

### Error Handling

The feature gracefully handles edge cases:
- Empty or very short posts return empty signature
- Missing signatures during initial build return empty results
- Posts without similarity scores are excluded from results

## Further Reading

- [MinHash on Wikipedia](https://en.wikipedia.org/wiki/MinHash)
- [Jaccard Index on Wikipedia](https://en.wikipedia.org/wiki/Jaccard_index)
- [Locality-Sensitive Hashing (LSH)](https://en.wikipedia.org/wiki/Locality-sensitive_hashing)
- [Mining of Massive Datasets - Chapter 3](http://www.mmds.org/) - Free textbook covering MinHash and LSH in depth

## Limitations

- The feature only works with posts that have text content (not pure images/galleries)
- Very short posts may not find good matches
- The algorithm is language-agnostic but works best with space-separated languages
- Similarity is based on lexical overlap, not semantic meaning

## Future Enhancements

Potential improvements for future versions:

- **TF-IDF weighting**: Weight rare terms more heavily than common terms
- **LSH (Locality-Sensitive Hashing)**: Further optimize large-scale similarity search
- **Semantic embeddings**: Use vector embeddings for semantic similarity
- **Configurable result count**: Allow users to set how many related posts to show
- **Similarity threshold**: Only show posts above a minimum similarity score
