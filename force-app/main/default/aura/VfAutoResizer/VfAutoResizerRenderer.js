({
  afterRender: function () {
    this.superAfterRender();

    if (window.__vfAutoResizerInstalled) return;
    window.__vfAutoResizerInstalled = true;

    function findVfFrame() {
      // Salesforce uses vfFrameId_ or VFFrameId_ depending on context
      var f =
        document.querySelector('iframe[id^="vfFrameId_"]') ||
        document.querySelector('iframe[id^="VFFrameId_"]');
      if (f) return f;

      var iframes = document.getElementsByTagName("iframe");
      for (var i = 0; i < iframes.length; i++) {
        var id = iframes[i].id || "";
        var src = iframes[i].src || "";
        if (
          id.indexOf("vfFrameId_") === 0 ||
          id.indexOf("VFFrameId_") === 0 ||
          src.indexOf("/apex/") !== -1
        )
          return iframes[i];
      }
      return null;
    }

    function setHeightUpChain(el, px) {
      var cur = el;
      for (var i = 0; i < 10 && cur; i++) {
        cur.style.height = px + "px";
        cur.style.minHeight = px + "px";
        cur = cur.parentElement;
      }
    }

    window.addEventListener("message", function (e) {
      if (!e.data || e.data.type !== "vfResize") return;

      var px = Number(e.data.height || 800);
      if (!Number.isFinite(px) || px < 100) return;

      var frame = findVfFrame();
      if (!frame) return;

      frame.style.height = px + "px";
      frame.style.minHeight = px + "px";
      setHeightUpChain(frame, px);
    });
  }
});
