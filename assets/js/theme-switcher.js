let isLight = localStorage.getItem('isLight') === "true";
const html = document.documentElement;
const switchTheme = document.getElementById("switch_theme");

function setTheme() {
  localStorage.setItem('isLight', isLight)
  // Set light or dark theme for picocss
  html.setAttribute("data-theme", isLight ? "light" : "dark");
  // Set light or dark theme for hljs too
  document.getElementById("hljscss").href = isLight
    ? "https://unpkg.com/@highlightjs/cdn-assets@11.7.0/styles/a11y-light.min.css"
    : "https://unpkg.com/@highlightjs/cdn-assets@11.7.0/styles/a11y-dark.min.css";
}

document.addEventListener("DOMContentLoaded", () => {
  setTheme();
});
switchTheme.addEventListener("click", (e) => {
  isLight = !isLight;
  setTheme();
});
