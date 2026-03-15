import { defineConfig } from 'vitepress'
import { writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { Feed } from 'feed'

// ── Constants ──────────────────────────────────────────────────────────────────
const SITE_URL = 'https://iceunit.com'
const SITE_NAME = 'CachyOS on MacBook Air 2020'
const SITE_DESCRIPTION =
  'Complete guide to installing and optimising CachyOS on the 2020 Intel MacBook Air (MacBookAir9,1) with T2 chip support.'
const OG_IMAGE_PATH = '/og-image.png'
const OG_IMAGE_ALT =
  'CachyOS on MacBook Air 2020 — installation and optimisation guide'
const REPO_URL =
  'https://github.com/sebastienrousseau/cachyos-macbook-intel-2020'
const AUTHOR = 'Sebastien Rousseau'

// ── Helpers ────────────────────────────────────────────────────────────────────

/**
 * Map file path to page type for schema selection.
 */
function getPageType(relativePath) {
  if (relativePath === 'index.md') return 'home'
  if (relativePath === 'guide/faq.md') return 'faq'
  if (relativePath.startsWith('guide/')) return 'guide'
  if (relativePath.startsWith('scripts/')) return 'script'
  if (relativePath === 'changelog.md') return 'changelog'
  return 'page'
}

/**
 * Map pageType to schema.org @type.
 */
function getSchemaType(pageType) {
  const map = {
    home: 'WebPage',
    guide: 'TechArticle',
    script: 'SoftwareSourceCode',
    faq: 'FAQPage',
    changelog: 'Article',
    page: 'WebPage',
  }
  return map[pageType] || 'WebPage'
}

/**
 * Build BreadcrumbList itemListElement array.
 */
function buildBreadcrumbs(page, pageTitle) {
  const items = [
    { '@type': 'ListItem', position: 1, name: 'Home', item: SITE_URL + '/' },
  ]

  const segments = page.replace(/\.html$/, '').split('/').filter(Boolean)
  let path = ''

  for (let i = 0; i < segments.length; i++) {
    path += '/' + segments[i]
    items.push({
      '@type': 'ListItem',
      position: i + 2,
      name: i === segments.length - 1 ? pageTitle : segments[i].charAt(0).toUpperCase() + segments[i].slice(1),
      item: SITE_URL + path,
    })
  }

  return items
}

/**
 * Extract FAQ entries from rendered HTML (H2 question / following content as answer).
 */
function extractFaqFromContent(content) {
  if (!content) return []
  const faqEntries = []
  const h2Regex = /<h2[^>]*>(.*?)<\/h2>/gi
  const parts = content.split(h2Regex)

  // parts[0] is before first H2, then alternating: heading text, content after heading
  for (let i = 1; i < parts.length; i += 2) {
    const question = parts[i].replace(/<[^>]+>/g, '').trim()
    const answer = (parts[i + 1] || '')
      .replace(/<[^>]+>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 500)
    if (question && answer) {
      faqEntries.push({ question, answer })
    }
  }
  return faqEntries
}

/**
 * Generate JSON-LD structured data objects for a page.
 */
function generateJsonLd({ pageType, title, description, canonicalUrl, page, content }) {
  const schemas = []

  // WebSite schema (home page only)
  if (pageType === 'home') {
    schemas.push({
      '@context': 'https://schema.org',
      '@type': 'WebSite',
      name: SITE_NAME,
      url: SITE_URL,
      description: SITE_DESCRIPTION,
      author: { '@type': 'Person', name: AUTHOR },
    })
  }

  // Main page schema
  const mainSchema = {
    '@context': 'https://schema.org',
    '@type': getSchemaType(pageType),
    headline: title,
    description,
    url: canonicalUrl,
    author: { '@type': 'Person', name: AUTHOR },
    publisher: {
      '@type': 'Organization',
      name: 'IceUnit',
      url: SITE_URL,
    },
  }

  if (pageType === 'script') {
    mainSchema.programmingLanguage = 'Bash'
    mainSchema.runtimePlatform = 'Linux'
  }

  schemas.push(mainSchema)

  // FAQ schema
  if (pageType === 'faq' && content) {
    const faqEntries = extractFaqFromContent(content)
    if (faqEntries.length > 0) {
      schemas.push({
        '@context': 'https://schema.org',
        '@type': 'FAQPage',
        mainEntity: faqEntries.map((entry) => ({
          '@type': 'Question',
          name: entry.question,
          acceptedAnswer: {
            '@type': 'Answer',
            text: entry.answer,
          },
        })),
      })
    }
  }

  // BreadcrumbList
  schemas.push({
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: buildBreadcrumbs(page, title),
  })

  return schemas
}

// ── Config ─────────────────────────────────────────────────────────────────────
export default defineConfig({
  // ── Site metadata ──────────────────────────────────────────────────────────
  title: SITE_NAME,
  description: SITE_DESCRIPTION,
  lang: 'en-US',

  // ── GitHub Pages base path ─────────────────────────────────────────────────
  base: '/',

  // ── Last updated timestamps ────────────────────────────────────────────────
  lastUpdated: true,

  // ── Clean URLs ─────────────────────────────────────────────────────────────
  cleanUrls: true,

  // ── Head tags (static, site-wide) ──────────────────────────────────────────
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' }],
    ['meta', { name: 'theme-color', content: '#a6e3a1' }],
    [
      'link',
      {
        rel: 'alternate',
        type: 'application/rss+xml',
        title: SITE_NAME,
        href: '/feed.xml',
      },
    ],
  ],

  // ── Sitemap ────────────────────────────────────────────────────────────────
  sitemap: {
    hostname: SITE_URL,
    transformItems(items) {
      return items.filter((item) => item.url !== 'troubleshooting')
    },
  },

  // ── transformPageData: auto-detect pageType ────────────────────────────────
  transformPageData(pageData) {
    pageData.pageType = getPageType(pageData.relativePath)
  },

  // ── transformHead: per-page SEO tags ───────────────────────────────────────
  transformHead(context) {
    const { pageData, siteData } = context
    const head = []

    const relativePath = pageData.relativePath
    const pageType = pageData.pageType || getPageType(relativePath)
    const title = pageData.title || siteData.title
    const description =
      pageData.frontmatter?.description || pageData.description || siteData.description

    // Canonical URL
    const pagePath = relativePath
      .replace(/index\.md$/, '')
      .replace(/\.md$/, '')
    const canonicalUrl = `${SITE_URL}/${pagePath}`

    head.push(['link', { rel: 'canonical', href: canonicalUrl }])

    // Robots
    const noindex = pageData.frontmatter?.noindex
    head.push([
      'meta',
      {
        name: 'robots',
        content: noindex ? 'noindex, nofollow' : 'index, follow',
      },
    ])

    // Open Graph
    head.push(['meta', { property: 'og:title', content: title }])
    head.push(['meta', { property: 'og:description', content: description }])
    head.push(['meta', { property: 'og:url', content: canonicalUrl }])
    head.push([
      'meta',
      { property: 'og:image', content: SITE_URL + OG_IMAGE_PATH },
    ])
    head.push(['meta', { property: 'og:image:width', content: '1200' }])
    head.push(['meta', { property: 'og:image:height', content: '630' }])
    head.push(['meta', { property: 'og:image:alt', content: OG_IMAGE_ALT }])
    head.push(['meta', { property: 'og:site_name', content: SITE_NAME }])
    head.push(['meta', { property: 'og:locale', content: 'en_US' }])
    head.push([
      'meta',
      {
        property: 'og:type',
        content: pageType === 'home' ? 'website' : 'article',
      },
    ])

    // Article timestamps (non-home pages)
    if (pageType !== 'home') {
      const lastUpdated = pageData.lastUpdated
      if (lastUpdated) {
        const isoDate = new Date(lastUpdated).toISOString()
        head.push([
          'meta',
          { property: 'article:modified_time', content: isoDate },
        ])
      }
      head.push([
        'meta',
        { property: 'article:author', content: AUTHOR },
      ])
    }

    // Twitter Card
    head.push([
      'meta',
      { name: 'twitter:card', content: 'summary_large_image' },
    ])
    head.push(['meta', { name: 'twitter:title', content: title }])
    head.push([
      'meta',
      { name: 'twitter:description', content: description },
    ])
    head.push([
      'meta',
      { name: 'twitter:image', content: SITE_URL + OG_IMAGE_PATH },
    ])
    head.push([
      'meta',
      { name: 'twitter:image:alt', content: OG_IMAGE_ALT },
    ])

    // JSON-LD
    const schemas = generateJsonLd({
      pageType,
      title,
      description,
      canonicalUrl,
      page: pagePath,
      content: context.content,
    })

    for (const schema of schemas) {
      head.push([
        'script',
        { type: 'application/ld+json' },
        JSON.stringify(schema),
      ])
    }

    return head
  },

  // ── buildEnd: generate RSS feed ────────────────────────────────────────────
  async buildEnd(siteConfig) {
    const feed = new Feed({
      title: SITE_NAME,
      description: SITE_DESCRIPTION,
      id: SITE_URL,
      link: SITE_URL,
      language: 'en-US',
      copyright: `Copyright © 2026 IceUnit (ICU)`,
      author: { name: AUTHOR, link: SITE_URL },
    })

    // Parse changelog entries
    const changelogEntries = [
      {
        title: 'v1.1.0 — March 2026',
        date: new Date('2026-03-08'),
        description:
          'Added --dry-run and --help flags, 148 unit tests, Docker-based CI, and security hardening.',
        link: `${SITE_URL}/changelog`,
      },
      {
        title: 'v1.0.0 — March 2026',
        date: new Date('2026-03-01'),
        description:
          'Initial public release. All scripts field-tested on MacBook Air 2020 (MacBookAir9,1) running CachyOS kernel 6.19.x.',
        link: `${SITE_URL}/changelog`,
      },
    ]

    for (const entry of changelogEntries) {
      feed.addItem({
        title: entry.title,
        id: entry.link,
        link: entry.link,
        description: entry.description,
        date: entry.date,
        author: [{ name: AUTHOR }],
      })
    }

    const outDir = siteConfig.outDir
    writeFileSync(resolve(outDir, 'feed.xml'), feed.rss2())
  },

  // ── Theme config ───────────────────────────────────────────────────────────
  themeConfig: {
    // ── Logo & site name ──────────────────────────────────────────────────
    logo: '/logo.svg',
    siteTitle: 'CachyOS · MacBook Air 2020',

    // ── Top navigation ────────────────────────────────────────────────────
    nav: [
      {
        text: 'Guide',
        link: '/guide/introduction',
        activeMatch: '/guide/',
      },
      {
        text: 'Scripts',
        link: '/scripts/overview',
        activeMatch: '/scripts/',
      },
      {
        text: 'Workstation',
        link: '/workstation/overview',
        activeMatch: '/workstation/',
      },
      {
        text: 'Resources',
        items: [
          { text: 'CachyOS Wiki', link: 'https://wiki.cachyos.org' },
          { text: 'T2 Linux Project', link: 'https://t2linux.org' },
          {
            text: 'arch-mact2 Mirror',
            link: 'https://mirror.funami.tech/arch-mact2/',
          },
        ],
      },
      {
        text: 'Changelog',
        link: '/changelog',
      },
    ],

    // ── Sidebar ───────────────────────────────────────────────────────────
    sidebar: {
      '/guide/': [
        {
          text: 'Getting Started',
          items: [
            { text: 'Introduction', link: '/guide/introduction' },
            { text: 'Hardware Specifications', link: '/guide/hardware' },
            { text: 'Hardware Status', link: '/guide/hardware-status' },
          ],
        },
        {
          text: 'Pre-Installation',
          items: [
            {
              text: 'Disable T2 Security',
              link: '/guide/disable-t2-security',
            },
            { text: 'Wi-Fi Firmware', link: '/guide/wifi-firmware' },
            { text: 'Create Bootable USB', link: '/guide/bootable-usb' },
            { text: 'Partition Layout', link: '/guide/partition-layout' },
          ],
        },
        {
          text: 'Installation',
          items: [
            {
              text: 'Running the Installer',
              link: '/guide/installation',
            },
            { text: 'Bootloader: Limine', link: '/guide/bootloader' },
          ],
        },
        {
          text: 'Post-Installation',
          items: [
            { text: 'Thermal Setup', link: '/guide/thermal-setup' },
            { text: 'System Optimisation', link: '/guide/optimisation' },
            { text: 'Encrypted Code Vault', link: '/guide/vault' },
          ],
        },
        {
          text: 'Reference',
          items: [
            { text: 'Troubleshooting', link: '/guide/troubleshooting' },
            { text: 'FAQ', link: '/guide/faq' },
          ],
        },
      ],

      '/scripts/': [
        {
          text: 'Core Scripts',
          items: [
            { text: 'Overview', link: '/scripts/overview' },
            { text: '00 · System Init', link: '/scripts/00-system-init' },
            { text: '00 · Setup Vault', link: '/scripts/00-setup-vault' },
            {
              text: '01 · Thermal Setup',
              link: '/scripts/01-thermal-setup',
            },
            {
              text: '02 · Wi-Fi Firmware',
              link: '/scripts/02-wifi-firmware',
            },
            { text: '03 · Optimise', link: '/scripts/03-optimise' },
            { text: '04 · Bootloader', link: '/scripts/04-bootloader' },
            { text: '05 · Mount Vault', link: '/scripts/05-mount-vault' },
            {
              text: '06 · Unmount Vault',
              link: '/scripts/06-unmount-vault',
            },
            { text: '07 · Install Apps', link: '/scripts/07-install-apps' },
            { text: '99 · Verify Install', link: '/scripts/99-verify-install' },
          ],
        },
      ],

      '/workstation/': [
        {
          text: 'Workstation',
          items: [
            { text: 'Overview', link: '/workstation/overview' },
            { text: '00 · AI Dev Stack', link: '/workstation/00-ai-dev-workstation' },
            { text: '10 · GNOME Speed', link: '/workstation/10-gnome-productivity' },
            { text: '20 · DevOps Tools', link: '/workstation/20-devops-tools' },
            { text: '30 · Security Tools', link: '/workstation/30-security-tools' },
            { text: '40 · Dotfiles Link', link: '/workstation/40-dotfiles-link' },
          ],
        },
      ],
    },

    // ── Local search ──────────────────────────────────────────────────────
    search: {
      provider: 'local',
      options: {
        detailedView: true,
      },
    },

    // ── Edit link ─────────────────────────────────────────────────────────
    editLink: {
      pattern: REPO_URL + '/edit/main/docs/:path',
      text: 'Edit this page on GitHub',
    },

    // ── Footer ────────────────────────────────────────────────────────────
    footer: {
      message:
        'Released under the MIT License. <a href="/accessibility">Accessibility</a> · <a href="/privacy">Privacy</a>',
      copyright: 'Copyright © 2026 IceUnit (ICU)',
    },

    // ── Social links ──────────────────────────────────────────────────────
    socialLinks: [{ icon: 'github', link: REPO_URL }],

    // ── Outline depth ─────────────────────────────────────────────────────
    outline: {
      level: [2, 3],
      label: 'On this page',
    },

    // ── Last updated text ─────────────────────────────────────────────────
    lastUpdated: {
      text: 'Updated at',
      formatOptions: {
        dateStyle: 'full',
        timeStyle: 'short',
      },
    },

    // ── Doc footer navigation ─────────────────────────────────────────────
    docFooter: {
      prev: 'Previous',
      next: 'Next',
    },

    // ── Custom 404 page ───────────────────────────────────────────────────
    notFound: {
      title: 'Page Not Found',
      quote:
        'The page you are looking for does not exist or has been moved.',
      linkText: 'Go to Home',
      linkLabel: 'Return to the home page',
    },
  },

  // ── Markdown options ───────────────────────────────────────────────────────
  markdown: {
    lineNumbers: true,
    theme: {
      light: 'catppuccin-latte',
      dark: 'catppuccin-mocha',
    },
  },
})
