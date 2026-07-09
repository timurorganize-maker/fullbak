/**
 * Applies the system color scheme before hydration to avoid a flash,
 * and keeps it in sync with the OS setting (auto light/dark per spec).
 */
export function ThemeInit() {
  const code = `
    (function () {
      try {
        var mq = window.matchMedia('(prefers-color-scheme: dark)');
        function apply() {
          document.documentElement.classList.toggle('dark', mq.matches);
        }
        apply();
        mq.addEventListener('change', apply);
      } catch (e) {}
    })();
  `;
  return <script dangerouslySetInnerHTML={{ __html: code }} />;
}
