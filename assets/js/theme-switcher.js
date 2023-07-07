let isLight = true
const html = document.documentElement
const switchTheme = document.getElementById('theme_switcher')
const os_default = '💻'
const sun = '🌞'
const moon = '🌙'

document.addEventListener('DOMContentLoaded', () => {
  switchTheme.innerHTML = os_default
  html.setAttribute('data-theme', 'auto')
  switchTheme.setAttribute('data-tooltip', 'os theme')
  switchTheme.focus()
  removeTooltip(3000)
})
switchTheme.addEventListener('click', (e)=> {
  e.preventDefault()
  isLight = !isLight
  html.setAttribute('data-theme', isLight? 'light':'dark')
  switchTheme.innerHTML = isLight? sun : moon
  switchTheme.setAttribute('data-tooltip', `theme ${isLight?'light':'dark'}`)
  removeTooltip()
})
const removeTooltip = (timeInt = 1750) => {
  setTimeout(()=>{
    switchTheme.blur()
  },timeInt)
}
