(function () {
  var KEY = "line24.legal.locale";

  function current() {
    try {
      var saved = localStorage.getItem(KEY);
      if (saved === "uk" || saved === "en") return saved;
    } catch (_) {}
    var nav = (navigator.language || "uk").toLowerCase();
    return nav.indexOf("uk") === 0 || nav.indexOf("ru") === 0 ? "uk" : "en";
  }

  function apply(locale) {
    document.documentElement.lang = locale;
    document.querySelectorAll(".i18n").forEach(function (el) {
      var match = el.getAttribute("data-locale") === locale;
      el.hidden = !match;
    });
    document.querySelectorAll("[data-set-locale]").forEach(function (btn) {
      btn.setAttribute(
        "aria-pressed",
        btn.getAttribute("data-set-locale") === locale ? "true" : "false"
      );
    });
    try {
      localStorage.setItem(KEY, locale);
    } catch (_) {}
  }

  document.addEventListener("DOMContentLoaded", function () {
    apply(current());
    document.querySelectorAll("[data-set-locale]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        apply(btn.getAttribute("data-set-locale"));
      });
    });
  });
})();
