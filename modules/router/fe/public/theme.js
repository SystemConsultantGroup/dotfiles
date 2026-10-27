(() => {
  let theme = "system";
  try {
    const saved = localStorage.getItem("router-theme");
    if (["light", "dark"].includes(saved)) theme = saved;
  } catch {
    // Storage may be unavailable in private or restricted browsers.
  }
  const dark =
    theme === "dark" ||
    (theme === "system" && matchMedia("(prefers-color-scheme: dark)").matches);
  document.documentElement.classList.toggle("dark", dark);
  document.documentElement.style.colorScheme = dark ? "dark" : "light";
})();
