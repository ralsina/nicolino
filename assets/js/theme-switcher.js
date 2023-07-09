let isLight = false;
const html = document.documentElement;
const switchTheme = document.getElementById("switch_theme");

document.addEventListener("DOMContentLoaded", () => {
  html.setAttribute("data-theme", "dark");
});
switchTheme.addEventListener("click", (e) => {
  isLight = !isLight;
  // Set light or dark theme for picocss
  html.setAttribute("data-theme", isLight ? "light" : "dark");
  // Set light or dark theme for hljs too
  document.getElementById("hljscss").href = isLight
    ? "https://unpkg.com/@highlightjs/cdn-assets@11.7.0/styles/a11y-light.min.css"
    : "https://unpkg.com/@highlightjs/cdn-assets@11.7.0/styles/a11y-dark.min.css";
});
