import DefaultTheme from 'vitepress/theme'
import { h } from 'vue'
import './custom.css'
import VerifiedOn from './VerifiedOn.vue'

export default {
  extends: DefaultTheme,
  Layout() {
    return h(DefaultTheme.Layout, null, {
      'doc-after': () => h(VerifiedOn)
    })
  }
}
