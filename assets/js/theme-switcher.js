let isLight = true
const html = document.documentElement
const switchTheme = document.getElementById('switch_theme')

document.addEventListener('DOMContentLoaded', () => {
  html.setAttribute('data-theme', 'light')
})
switchTheme.addEventListener('click', (e)=> {
  isLight = !isLight
  html.setAttribute('data-theme', isLight? 'light':'dark')
  removeTooltip()
})
