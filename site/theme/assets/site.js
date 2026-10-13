(function () {
  "use strict";
  var root = document.documentElement;

  function storedScheme(value) {
    try {
      if (value === undefined) return localStorage.getItem("scheme");
      localStorage.setItem("scheme", value);
    } catch (e) {
      return null;
    }
  }

  var toggle = document.querySelector(".scheme-toggle");
  if (toggle) {
    toggle.addEventListener("click", function () {
      var current = root.dataset.scheme ||
        (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
      var next = current === "dark" ? "light" : "dark";
      root.dataset.scheme = next;
      storedScheme(next);
    });
  }

  var topbar = document.querySelector(".topbar");
  if (topbar) {
    var onScroll = function () { topbar.classList.toggle("is-scrolled", window.scrollY > 8); };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
  }

  // The rail is a <details> so that small screens get a "Contents" button without JS.
  // On wide screens it must stay open and its label must not act as a button.
  var rail = document.querySelector(".rail");
  if (rail) {
    var wide = matchMedia("(min-width: 64em)");
    var syncRail = function () { rail.open = wide.matches; };
    syncRail();
    wide.addEventListener("change", syncRail);
    rail.querySelector(".rail-label").addEventListener("click", function (event) {
      if (wide.matches) event.preventDefault();
    });
    var current = rail.querySelector(".is-current");
    if (current && wide.matches) {
      var top = current.offsetTop - rail.clientHeight / 3;
      if (top > 0) rail.scrollTop = top;
    }
  }

  // Mark the step being read in the rail.
  var stepLinks = document.querySelectorAll(".rail-steps a");
  if (stepLinks.length && "IntersectionObserver" in window) {
    var byId = {};
    stepLinks.forEach(function (link) { byId[decodeURIComponent(link.hash.slice(1))] = link; });
    var headings = Array.prototype.filter.call(document.querySelectorAll(".prose h2[id]"), function (h) { return byId[h.id]; });
    var mark = function (id) {
      stepLinks.forEach(function (link) { link.classList.remove("is-here"); });
      if (byId[id]) byId[id].classList.add("is-here");
    };
    var observer = new IntersectionObserver(function () {
      var passed = headings.filter(function (h) { return h.getBoundingClientRect().top < window.innerHeight * 0.3; });
      mark(passed.length ? passed[passed.length - 1].id : null);
    }, { rootMargin: "0px 0px -60% 0px" });
    headings.forEach(function (h) { observer.observe(h); });
  }

  // Search: Pagefind is loaded the first time the dialog opens.
  var dialog = document.getElementById("search");
  var opener = document.querySelector(".search-open");
  var searchLoaded = false;

  function loadSearch() {
    if (searchLoaded) return;
    searchLoaded = true;
    var mount = document.getElementById("search-ui");
    var bundle = mount.dataset.bundle;
    var css = document.createElement("link");
    css.rel = "stylesheet";
    css.href = bundle + "pagefind-ui.css";
    document.head.appendChild(css);
    var script = document.createElement("script");
    script.src = bundle + "pagefind-ui.js";
    script.onload = function () {
      /* global PagefindUI */
      new PagefindUI({ element: "#search-ui", bundlePath: bundle, showImages: false, resetStyles: false, autofocus: true });
      var input = mount.querySelector("input");
      if (input) input.focus();
    };
    script.onerror = function () {
      mount.textContent = "Search is not available in this build. Run scripts/build-site.py to create the index.";
    };
    document.head.appendChild(script);
  }

  function openSearch() {
    if (!dialog || dialog.open) return;
    loadSearch();
    dialog.showModal();
    var input = dialog.querySelector("input");
    if (input) input.focus();
  }

  if (opener && dialog) {
    opener.addEventListener("click", openSearch);
    dialog.addEventListener("click", function (event) {
      if (event.target === dialog) dialog.close();
    });
    document.addEventListener("keydown", function (event) {
      var typing = /^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement.tagName) || document.activeElement.isContentEditable;
      if (event.key === "/" && !typing && !event.metaKey && !event.ctrlKey) {
        event.preventDefault();
        openSearch();
      }
    });
  }
})();
