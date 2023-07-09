let isLight = false
const html = document.documentElement
const switchTheme = document.getElementById('switch_theme')

document.addEventListener('DOMContentLoaded', () => {
  html.setAttribute('data-theme', 'dark')
})
switchTheme.addEventListener('click', (e)=> {
  isLight = !isLight
  html.setAttribute('data-theme', isLight? 'light':'dark')
})
