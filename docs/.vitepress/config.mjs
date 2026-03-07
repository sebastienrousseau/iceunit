import { defineConfig } from 'vitepress'

export default defineConfig({
  // ── Site metadata ──────────────────────────────────────────────────────────
  title: 'CachyOS on MacBook Air 2020',
  description: 'Complete guide to installing and optimising CachyOS on the 2020 Intel MacBook Air (MacBookAir9,1) with T2 chip support.',
  lang: 'en-US',

  // ── GitHub Pages base path ─────────────────────────────────────────────────
  // Matches https://sebastienrousseau.github.io/cachyos-macbook-intel-2020/
  base: '/',

  // ── Last updated timestamps ────────────────────────────────────────────────
  lastUpdated: true,

  // ── Clean URLs ─────────────────────────────────────────────────────────────
  cleanUrls: true,

  // ── Head tags ─────────────────────────────────────────────────────────────
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/cachyos-macbook-intel-2020/favicon.svg' }],
    ['meta', { name: 'theme-color', content: '#a6e3a1' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'CachyOS on MacBook Air 2020' }],
    ['meta', { property: 'og:description', content: 'Complete guide to installing and optimising CachyOS on the 2020 Intel MacBook Air with T2 chip support.' }],
  ],

  // ── Theme config ───────────────────────────────────────────────────────────
  themeConfig: {

    // ── Logo & site name ──────────────────────────────────────────────────
    logo: '/logo.svg',
    siteTitle: 'CachyOS · MacBook Air 2020',

    // ── Top navigation ────────────────────────────────────────────────────
    nav: [
      { text: 'Guide', link: '/guide/introduction', activeMatch: '/guide/' },
      { text: 'Scripts', link: '/scripts/overview', activeMatch: '/scripts/' },
      {
        text: 'Resources',
        items: [
          { text: 'CachyOS Wiki', link: 'https://wiki.cachyos.org' },
          { text: 'T2 Linux Project', link: 'https://t2linux.org' },
          { text: 'arch-mact2 Mirror', link: 'https://mirror.funami.tech/arch-mact2/' },
        ]
      },
      {
        text: 'Changelog',
        link: '/changelog'
      }
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
          ]
        },
        {
          text: 'Pre-Installation',
          items: [
            { text: 'Disable T2 Security', link: '/guide/disable-t2-security' },
            { text: 'Wi-Fi Firmware', link: '/guide/wifi-firmware' },
            { text: 'Create Bootable USB', link: '/guide/bootable-usb' },
            { text: 'Partition Layout', link: '/guide/partition-layout' },
          ]
        },
        {
          text: 'Installation',
          items: [
            { text: 'Running the Installer', link: '/guide/installation' },
            { text: 'Bootloader: Limine', link: '/guide/bootloader' },
          ]
        },
        {
          text: 'Post-Installation',
          items: [
            { text: '⚠️ Thermal Setup', link: '/guide/thermal-setup' },
            { text: 'System Optimisation', link: '/guide/optimisation' },
            { text: 'Encrypted Code Vault', link: '/guide/vault' },
          ]
        },
        {
          text: 'Reference',
          items: [
            { text: 'Troubleshooting', link: '/guide/troubleshooting' },
            { text: 'FAQ', link: '/guide/faq' },
          ]
        }
      ],

      '/scripts/': [
        {
          text: 'Scripts',
          items: [
            { text: 'Overview', link: '/scripts/overview' },
            { text: '00 · Setup Vault', link: '/scripts/00-setup-vault' },
            { text: '01 · Thermal Setup', link: '/scripts/01-thermal-setup' },
            { text: '02 · Wi-Fi Firmware', link: '/scripts/02-wifi-firmware' },
            { text: '03 · Optimise', link: '/scripts/03-optimise' },
            { text: '04 · Bootloader', link: '/scripts/04-bootloader' },
            { text: '05 · Mount Vault', link: '/scripts/05-mount-vault' },
            { text: '06 · Unmount Vault', link: '/scripts/06-unmount-vault' },
          ]
        }
      ]
    },

    // ── Local search (built-in, no Algolia needed) ─────────────────────────
    search: {
      provider: 'local',
      options: {
        detailedView: true
      }
    },

    // ── Edit link ─────────────────────────────────────────────────────────
    editLink: {
      pattern: 'https://github.com/sebastienrousseau/cachyos-macbook-intel-2020/edit/main/docs/:path',
      text: 'Edit this page on GitHub'
    },

    // ── Footer ────────────────────────────────────────────────────────────
    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2024–present Sebastien Rousseau'
    },

    // ── Social links ──────────────────────────────────────────────────────
    socialLinks: [
      { icon: 'github', link: 'https://github.com/sebastienrousseau/cachyos-macbook-intel-2020' }
    ],

    // ── Outline depth (show h2 + h3 in right sidebar) ─────────────────────
    outline: {
      level: [2, 3],
      label: 'On this page'
    },

    // ── Last updated text ─────────────────────────────────────────────────
    lastUpdated: {
      text: 'Updated at',
      formatOptions: {
        dateStyle: 'full',
        timeStyle: 'short'
      }
    },

    // ── Doc footer navigation ─────────────────────────────────────────────
    docFooter: {
      prev: 'Previous',
      next: 'Next'
    },
  },

  // ── Markdown options ───────────────────────────────────────────────────────
  markdown: {
    lineNumbers: true,
    theme: {
      light: 'catppuccin-latte',
      dark: 'catppuccin-mocha'   // matches CachyOS default theme
    }
  },
})
