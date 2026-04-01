<script setup>
import { useData } from 'vitepress'
const { frontmatter } = useData()
</script>

<template>
  <div v-if="frontmatter.verifiedOn" class="verified-on">
    <span class="verified-icon">✓</span>
    Verified on {{ new Date(frontmatter.verifiedOn + 'T00:00:00').toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' }) }}
    · MacBook Air 2020 · CachyOS 6.19.x-cachyos
  </div>
</template>

<style scoped>
.verified-on {
  margin-top: 2rem;
  padding: 0.75rem 1rem;
  border-top: 1px solid var(--vp-c-divider);
  font-size: 0.85rem;
  color: var(--vp-c-text-2);
}
.verified-icon {
  color: var(--vp-c-green-1);
  font-weight: bold;
  margin-right: 0.25rem;
}
</style>
