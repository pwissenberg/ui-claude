import Foundation

/// JavaScript and CSS injected into claude.ai to strip it down to a single
/// conversation and let the window's translucency show through.
enum WebChrome {
    /// Strips claude.ai down to a single conversation and makes it transparent so
    /// the window's vibrancy shows through.
    ///
    /// Selectors come from probing the live authenticated DOM (see `probeJS`):
    /// only `body` (`rgb(21,21,21)`) and `main.dframe-content` paint an opaque
    /// backdrop; every wrapper between them is already transparent.
    private static let css = """
    /* Let the window's translucency show through the page. */
    html, body { background: transparent !important; }
    main, main.dframe-content { background-color: transparent !important; }

    /* claude.ai paints its real backdrop with a full-bleed overlay div on top of
       main, so clearing html/body/main alone leaves the panel opaque. */
    div.pointer-events-none.absolute.inset-0 { background-color: transparent !important; }

    /* One conversation only - no sidebar, recents, or pinned list. The floating
       "Open sidebar" trigger is a separate <aside>, outside the panel that
       `[data-testid="sidebar"]` covers, and outlives it. */
    [data-testid="sidebar"],
    [data-testid="sidebar-pinned"],
    [data-testid="sidebar-recents"],
    aside.dframe-sidebar,
    .df-compact-trigger { display: none !important; }

    /* No app header - New Chat lives in the menu bar instead. */
    header.dframe-header { display: none !important; }

    /* Applied by the compact-mode script below. */
    .cc-hidden { display: none !important; }

    /* Compact mode: the window is only as tall as the composer, so the page's own
       full-height layout already fits it - the wrappers need no restructuring.
       Forcing height/flex on them collapses `main` (which is absolutely
       positioned) to 0x0, and every `w-full` descendant with it, which paints
       nothing at all. Suppressing scrollbars is the only rule needed here. */
    html.cc-compact, html.cc-compact body { overflow: hidden !important; }

    /* Compact mode is a single rounded bar, like the ChatGPT companion: the window
       frame IS the composer's frame. claude.ai draws its own opaque panel inside
       the window, which would otherwise read as a box inside a box and hide the
       translucency behind it. */
    html.cc-compact .cc-surface {
      background: transparent !important;
      border: 0 !important;
      border-radius: 0 !important;
      box-shadow: none !important;
    }

    /* In a conversation the composer still needs to read as a distinct input, but
       claude.ai's opaque panel is a black slab on a translucent window. A light
       translucent fill keeps the separation while matching the compact bar's
       material. */
    html:not(.cc-compact):not(.cc-solid) .cc-surface {
      background-color: rgba(255, 255, 255, 0.10) !important;
      border-color: rgba(255, 255, 255, 0.18) !important;
      box-shadow: none !important;
    }

    /* The composer is sticky, so the transcript scrolls *underneath* it. claude.ai
       hides that with a scrim fading to its own opaque surface - which we remove,
       because over a translucent window it reads as a black band. Blurring the
       backdrop instead obscures the text passing behind without painting a colour
       the window does not have, the way a macOS toolbar does. */
    html:not(.cc-compact):not(.cc-solid) div.sticky.bottom-0 {
      /* Blur only, no tint. A darkening fade was tried here as a belt-and-braces
         alongside the blur, and it read as a shadow smeared across the bottom of
         the panel - the blur alone hides the text passing behind. */
      -webkit-backdrop-filter: blur(24px) saturate(150%) !important;
      backdrop-filter: blur(24px) saturate(150%) !important;
      background-image: none !important;
      background-color: transparent !important;
    }

    /* The footer disclaimer sits below the composer in the sticky footer, where a
       440pt window has no room for it - it collides with the rounded bottom edge. */
    div.sticky.bottom-0 div.text-muted.text-center { display: none !important; }

    /* Lift the composer off the window's bottom edge. Flush against it, its own
       rounded box gets cut by the window's 22pt corners. */
    div.sticky.bottom-0 { padding-bottom: 10px !important; }

    /* Scrims claude.ai fades the transcript out with. They are built for its own
       solid background, so over a translucent window they read as a heavy black
       band above the composer. Tagged by clearScrims. */
    .cc-scrim,
    .cc-scrim::before,
    .cc-scrim::after {
      background-image: none !important;
      background-color: transparent !important;
    }

    /* The fade above the composer is drawn on the sticky footer's pseudo-elements,
       which no element-level rule reaches. */
    div.sticky.bottom-0::before,
    div.sticky.bottom-0::after {
      background-image: none !important;
      background-color: transparent !important;
    }

    /* Transient banners the layout script matches by text (see dismissBanners). */
    .cc-banner-hidden { display: none !important; }

    /* Tailwind names its gradient utilities, so this catches the fade scrims
       declaratively - including those drawn on pseudo-elements - rather than
       waiting for the JS sweep to notice them mid-response. Those scrims fade to
       claude.ai's own opaque surface, which over a translucent window reads as a
       black band across the panel. */
    html:not(.cc-solid) main [class*="gradient"],
    html:not(.cc-solid) main [class*="gradient"]::before,
    html:not(.cc-solid) main [class*="gradient"]::after {
      background-image: none !important;
    }

    /* Solid chat background, when translucent chat is switched off.
       claude.ai's conversation view is built for an opaque dark surface - its
       scrims, gradients and overlays all fade to it - so restoring that surface
       removes the whole class of artefacts at once, instead of patching them one
       element at a time. The compact bar stays translucent either way. */
    html.cc-solid:not(.cc-compact),
    html.cc-solid:not(.cc-compact) body,
    html.cc-solid:not(.cc-compact) main,
    html.cc-solid:not(.cc-compact) main.dframe-content {
      background-color: rgb(21, 21, 21) !important;
    }

    /* Muted text - the "Thinking…" line, timestamps, the effort label - is
       rgb(137,135,129), chosen for claude.ai's near-black surface. The translucent
       panel measures about rgb(129,129,129), so that text lands at roughly 1.02:1
       contrast against its own background: the same colour, effectively invisible.
       Tagged by brightenMuted, which measures luminance rather than guessing which
       token or utility class produced it. */
    html:not(.cc-solid) .cc-readable {
      color: rgba(255, 255, 255, 0.86) !important;
    }

    /* Tighten the composer's internals: 12pt between the input and the controls
       plus 14pt margins are proportions for a full-width window, and leave an
       obvious hole in a 440pt panel. The input row itself is left alone - it is
       sized by its content, so it still grows as the message wraps. */
    .cc-surface div.flex.flex-col[class*="gap-3"] {
      gap: 6px !important;
      margin: 10px 8px !important;
    }

    /* Reclaim horizontal space. Five nested containers inset the composer, costing
       36pt before the text starts and 30pt after it - 15% of a 440pt window given
       to margins that were sized for a full-width browser. The outermost 8pt is
       left alone so the text never touches the window edge. */
    .cc-surface {
      margin-left: 2px !important;
      margin-right: 2px !important;
    }
    html:not(.cc-solid) div.mx-auto.mt-4.w-full {
      padding-left: 0 !important;
      padding-right: 0 !important;
    }

    /* The input row carries 6pt of padding on the left and none on the right, so the
       text sits off-centre inside the composer and the box reads as badly fitted.
       Zeroing it squares the two sides up and gains the 6pt as line width. */
    .cc-surface div.overflow-y-auto.break-words {
      padding-left: 0 !important;
    }

    /* New-conversation button, injected into the header's actions slot. Styled to
       match the neighbouring controls rather than to stand out. */
    #cc-new-chat {
      appearance: none !important;
      -webkit-appearance: none !important;
      display: inline-flex !important;
      align-items: center !important;
      gap: 5px !important;
      margin-right: 6px !important;
      padding: 5px 10px !important;
      border: 1px solid rgba(255, 255, 255, 0.18) !important;
      border-radius: 8px !important;
      background: rgba(255, 255, 255, 0.10) !important;
      color: rgba(255, 255, 255, 0.92) !important;
      font: inherit !important;
      font-size: 12px !important;
      line-height: 1 !important;
      cursor: pointer !important;
    }
    #cc-new-chat:hover { background: rgba(255, 255, 255, 0.20) !important; }
    #cc-new-chat:active { background: rgba(255, 255, 255, 0.26) !important; }
    /* The compact bar is already an empty conversation, and has no header anyway. */
    html.cc-compact #cc-new-chat { display: none !important; }

    /* Slim, unobtrusive scrollbar in place of the default full-width one. */
    ::-webkit-scrollbar { width: 6px !important; height: 6px !important; }
    ::-webkit-scrollbar-track { background: transparent !important; }
    ::-webkit-scrollbar-thumb {
      background: rgba(255, 255, 255, 0.18) !important;
      border-radius: 3px !important;
    }
    """

    /// Injects `css` as a `<style>` element.
    ///
    /// A stylesheet in the document survives claude.ai's client-side navigation, so
    /// this only needs to run once per page load. `!important` throughout, because
    /// the app's own Tailwind utility classes would otherwise win on specificity.
    static var styleJS: String {
        """
        (() => {
          const ID = 'claude-companion-style';
          const CSS = \(jsStringLiteral(css));
          const apply = () => {
            if (document.getElementById(ID)) return;
            const style = document.createElement('style');
            style.id = ID;
            style.textContent = CSS;
            (document.head || document.documentElement).appendChild(style);
          };
          apply();
          document.addEventListener('DOMContentLoaded', apply);
        })();
        """
    }

    /// Collapses the page to just the composer when there is no conversation yet,
    /// and reports the height the window should be.
    ///
    /// The composer is isolated *structurally* - every sibling along its ancestor
    /// chain is hidden - rather than by hiding the greeting and header by name. The
    /// chain is what the DOM guarantees; Tailwind class names are not.
    static let layoutJS = """
    (() => {
      const HIDDEN = 'cc-hidden';
      const CHAIN = 'cc-chain';
      let last = '';

      // The <fieldset> wrapping the input is the visible rounded composer box.
      const composerBox = () => {
        const input = document.querySelector('[data-testid="chat-input"]');
        if (!input) return null;
        return input.closest('fieldset') || input.parentElement;
      };

      // claude.ai switches from /new to /chat/<id> once a conversation exists.
      const isCompact = () => !/^\\/chat\\//.test(location.pathname);

      // The composer's own painted panel - the largest element inside it drawing a
      // background. Tagged rather than named by class, because its Tailwind classes
      // are generated. The send button also paints, hence "largest", not "any".
      const tagSurface = (box) => {
        // Tag once and keep it. Re-evaluating each tick oscillates: the rule below
        // makes the tagged element transparent, so it stops being "the element with
        // a background", the tag moves elsewhere, its background returns, and the
        // composer's height flips back and forth forever.
        const existing = document.querySelector('.cc-surface');
        if (existing && box.contains(existing)) return;

        let best = null, bestArea = 0;
        const consider = (el) => {
          const bg = getComputedStyle(el).backgroundColor;
          if (!bg || bg === 'transparent') return;
          const m = bg.match(/rgba?\\(([^)]+)\\)/);
          if (m) {
            const parts = m[1].split(',').map((p) => parseFloat(p));
            if (parts.length === 4 && parts[3] === 0) return;
          }
          const r = el.getBoundingClientRect();
          const area = r.width * r.height;
          if (area > bestArea) { bestArea = area; best = el; }
        };
        consider(box);
        box.querySelectorAll('*').forEach(consider);
        if (best && !best.classList.contains('cc-surface')) {
          document.querySelectorAll('.cc-surface').forEach((e) => e.classList.remove('cc-surface'));
          best.classList.add('cc-surface');
        }
      };

      const isolate = (box) => {
        // Self-heal first. claude.ai is a React app that replaces subtrees, so an
        // element hidden during an earlier pass can end up on the composer's current
        // ancestor chain - which would hide the composer itself and leave an empty
        // window. Clearing the chain every tick makes the isolation re-entrant.
        let el = box;
        while (el && el !== document.body) {
          el.classList.remove(HIDDEN);
          el = el.parentElement;
        }

        // Climb only as far as <main>. Above it sits the app's layout scaffolding -
        // including a CSS Grid whose row sizing depends on which items exist. Hiding
        // an item there re-places the survivor into a content-sized row, and because
        // `main` is absolutely positioned and contributes no height, that row (and
        // everything below it) collapses to zero and paints nothing.
        el = box;
        let depth = 0;
        while (el && el.parentElement && depth++ < 12) {
          const parent = el.parentElement;
          for (const sib of parent.children) {
            if (sib !== el) sib.classList.add(HIDDEN);
          }
          parent.classList.add(CHAIN);
          if (parent.tagName === 'MAIN' || parent === document.body) break;
          el = parent;
        }
        document.documentElement.classList.add('cc-compact');
      };

      // Reports why the composer is not visible, so an empty window is diagnosable
      // from the log instead of needing a browser inspector.
      const diagnose = (box) => {
        const r = box.getBoundingClientRect();
        const parts = ['rect=' + Math.round(r.width) + 'x' + Math.round(r.height)
          + '+' + Math.round(r.top)];
        let el = box, depth = 0;
        while (el && el !== document.documentElement && depth++ < 12) {
          const s = getComputedStyle(el);
          if (s.display === 'none' || s.visibility === 'hidden' || s.opacity === '0'
              || el.classList.contains(HIDDEN)) {
            parts.push('BLOCKED at depth ' + depth + ': '
              + el.tagName.toLowerCase()
              + (el.className && typeof el.className === 'string'
                  ? '.' + el.className.trim().split(/\\s+/).slice(0, 3).join('.') : '')
              + ' display=' + s.display
              + ' visibility=' + s.visibility
              + ' opacity=' + s.opacity);
            break;
          }
          el = el.parentElement;
        }
        return parts.join(' | ');
      };

      const restore = () => {
        document.documentElement.classList.remove('cc-compact');
        document.querySelectorAll('.' + HIDDEN).forEach((e) => e.classList.remove(HIDDEN));
        document.querySelectorAll('.' + CHAIN).forEach((e) => e.classList.remove(CHAIN));
        document.querySelectorAll('.cc-surface').forEach((e) => e.classList.remove('cc-surface'));
      };

      // Transient overlays that cover the conversation in a window this small.
      // Matched by text because they carry no stable hook, and re-checked every
      // tick because they appear mid-response, long after load.
      const BANNERS = [/want to be notified/i, /enable (desktop )?notifications/i];
      const dismissBanners = () => {
        const input = document.querySelector('[data-testid="chat-input"]');
        document.querySelectorAll('div,section,aside').forEach((el) => {
          const text = (el.textContent || '').trim();
          // Short enough to be the banner itself rather than a container holding it
          // along with the conversation.
          const matches = !!text && text.length <= 120
            && BANNERS.some((re) => re.test(text));

          if (el.classList.contains('cc-banner-hidden')) {
            // Reversible: once the banner's text is gone this element is ordinary
            // again. Hiding permanently would strand whatever it holds now.
            if (!matches) el.classList.remove('cc-banner-hidden');
            return;
          }
          if (!matches) return;
          // Never hide anything containing the composer. claude.ai renders this
          // banner *inside* the composer's own wrapper, so matching on text alone
          // takes the composer down with it.
          if (input && el.contains(input)) return;
          const r = el.getBoundingClientRect();
          if (r.height < 30 || r.height > 240) return;
          el.classList.add('cc-banner-hidden');
        });
      };

      // Decorative fade-out gradients above the composer. They appear mid-response
      // alongside the thinking indicator, so they have to be swept for continuously
      // rather than once at load.
      //
      // Tagged once and never re-evaluated: the rule blanks the gradient, so a
      // second look would find no gradient, untag it, and flip forever.
      const clearScrims = () => {
        document.querySelectorAll('div').forEach((el) => {
          if (el.classList.contains('cc-scrim')) return;
          const s = getComputedStyle(el);
          const where = ['self', '::before', '::after'].find((w, i) => {
            const style = i === 0 ? s : getComputedStyle(el, w);
            return /gradient/.test(style.backgroundImage || '');
          });
          if (!where) return;
          // Decorative: a scrim carries no prose. A short label is allowed because
          // claude.ai puts its "Quick answer" button inside the band, and requiring
          // it to be empty would skip the very element that needs clearing.
          if ((el.textContent || '').trim().length > 40) return;
          const r = el.getBoundingClientRect();
          if (r.width < innerWidth * 0.6 || r.height < 40) return;
          el.classList.add('cc-scrim');
          post({ mode: 'diag', detail: 'scrim cleared (' + where + '): '
            + Math.round(r.width) + 'x' + Math.round(r.height)
            + ' at ' + Math.round(r.top)
            + ' ' + el.tagName.toLowerCase()
            + (typeof el.className === 'string' && el.className
                ? '.' + el.className.trim().split(/\\s+/).slice(0, 3).join('.') : '') });
        });
      };

      // Text too dark to read on the panel. Measured, not matched by class: the
      // muted colour here comes from neither --text-400 nor a `text-muted` utility,
      // so luminance is the only reliable signal.
      //
      // Tagged once, like the scrims: the rule lightens the text, so a second look
      // would find it readable, untag it, and flip back and forth.
      const brightenMuted = () => {
        document.querySelectorAll('main span, main a, main p, main time').forEach((el) => {
          if (el.classList.contains('cc-readable')) return;
          const own = Array.from(el.childNodes)
            .filter((n) => n.nodeType === 3)
            .map((n) => n.textContent.trim())
            .join('');
          if (!own) return;
          const m = getComputedStyle(el).color.match(/rgba?\\(([^)]+)\\)/);
          if (!m) return;
          const parts = m[1].split(',').map((p) => parseFloat(p));
          const lum = (0.2126 * parts[0] + 0.7152 * parts[1] + 0.0722 * parts[2]) / 255;
          if (lum > 0.62) return;
          el.classList.add('cc-readable');
        });
      };

      // A visible way to start a fresh conversation. Injected into claude.ai's own
      // header actions slot so it sits with the other controls, and re-added on
      // every tick because React replaces that subtree freely.
      //
      // It posts a message rather than navigating itself, so the button, the menu
      // item and ⌘N all end up in the same code path.
      const ensureNewChatButton = () => {
        if (document.getElementById('cc-new-chat')) return;
        const slot = document.querySelector('#dframe-header-actions-slot');
        if (!slot) return;
        const button = document.createElement('button');
        button.id = 'cc-new-chat';
        button.type = 'button';
        button.textContent = 'New';
        button.title = 'Start a new conversation (Cmd-N)';
        button.addEventListener('click', (event) => {
          event.preventDefault();
          event.stopPropagation();
          post({ mode: 'newChat' });
        });
        slot.insertBefore(button, slot.firstChild);
      };

      const tick = () => {
        ensureNewChatButton();
        dismissBanners();
        clearScrims();
        brightenMuted();
        const box = composerBox();
        if (!box) {
          if (last !== 'missing') {
            last = 'missing';
            post({ mode: 'diag', detail: 'composer element not found' });
          }
          return;
        }
        const compact = isCompact();
        // `isolate` is idempotent, so it can run every tick to catch newly rendered
        // siblings without the churn of removing and re-adding classes.
        // Tag the composer's painted panel in both modes: compact strips it so the
        // window frame becomes the composer, chat restyles it to match the blur.
        tagSurface(box);
        if (compact) {
          isolate(box);
        } else if (document.documentElement.classList.contains('cc-compact')) {
          restore();
        }

        const rect = box.getBoundingClientRect();
        const payload = compact ? 'compact:' + Math.round(rect.height) : 'chat';
        if (payload === last) return;
        last = payload;

        // A composer with no height means the layout collapsed; say why.
        if (compact && rect.height < 20) {
          post({ mode: 'diag', detail: diagnose(box) });
          return;
        }

        post({
          mode: compact ? 'compact' : 'chat',
          height: Math.round(rect.height),
          top: Math.round(rect.top),
          bodyHeight: Math.round(document.body.getBoundingClientRect().height)
        });
      };

      // Enter sends; Shift-Enter stays a newline.
      //
      // claude.ai's composer variant here ("composer-card-latch = classic") does not
      // send on a bare Enter, and exposes no preference to change that, so the key
      // is handled directly. Capture phase, so the page's own handler never runs and
      // the message cannot be sent twice.
      const SEND = '[data-testid="chat-input-send"]';
      const INPUT = '[data-testid="chat-input"]';
      document.addEventListener('keydown', (event) => {
        if (event.key !== 'Enter') return;
        if (event.metaKey || event.ctrlKey || event.altKey) return;
        // Mid-composition in an IME: Enter accepts the candidate, it does not send.
        if (event.isComposing || event.keyCode === 229) return;

        const input = document.querySelector(INPUT);
        if (!input || !(event.target === input || input.contains(event.target))) return;

        // Shift-Enter has to be handled too, not just ignored. This composer variant
        // sends on Shift-Enter, so leaving it alone would mean both keys send and
        // nothing inserts a newline.
        if (event.shiftKey) {
          event.preventDefault();
          event.stopPropagation();
          if (window.__ccDryRun) {
            window.__ccLastEnter = 'would insert newline';
            return;
          }
          if (!document.execCommand('insertLineBreak', false, null)) {
            document.execCommand('insertText', false, '\\n');
          }
          return;
        }

        const button = document.querySelector(SEND);
        // Nothing to send: leave the page to do whatever it would have done.
        if (!button || button.disabled) return;

        event.preventDefault();
        event.stopPropagation();
        if (window.__ccDryRun) {
          window.__ccLastEnter = 'would send';
          return;
        }
        button.click();
      }, true);

      const post = (payload) => {
        if (window.webkit && window.webkit.messageHandlers
            && window.webkit.messageHandlers.layout) {
          window.webkit.messageHandlers.layout.postMessage(payload);
        }
      };

      // The page is a single-page app, so poll rather than relying on load events.
      setInterval(tick, 400);
      tick();
    })();
    """

    /// Encodes a string as a JavaScript literal via JSON.
    ///
    /// Interpolating CSS straight into a template literal is a trap: a single
    /// backtick or `${` in a comment silently breaks the whole injection script.
    private static func jsStringLiteral(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: string, options: [.fragmentsAllowed]),
              let literal = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return literal
    }

    /// Diagnostic probe: dumps the tree inside `main` so the greeting, header icons,
    /// composer, and transcript can be targeted by real selectors.
    static let structureProbeJS = """
    (() => {
      const root = document.querySelector('main') || document.body;
      const out = [];
      const walk = (el, depth) => {
        if (depth > 7 || out.length > 60) return;
        const r = el.getBoundingClientRect();
        if (r.width < 16 || r.height < 12) return;
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 3).join('.')
          : '';
        const own = Array.from(el.childNodes)
          .filter((n) => n.nodeType === 3)
          .map((n) => n.textContent.trim())
          .join(' ')
          .slice(0, 28);
        out.push('  '.repeat(depth)
          + el.tagName.toLowerCase()
          + (el.id ? '#' + el.id : '')
          + (el.getAttribute('data-testid') ? '@' + el.getAttribute('data-testid') : '')
          + (el.getAttribute('aria-label') ? '~' + el.getAttribute('aria-label') : '')
          + cls
          + ' ' + Math.round(r.width) + 'x' + Math.round(r.height)
          + '+' + Math.round(r.top)
          + (own ? ' "' + own + '"' : ''));
        Array.from(el.children).forEach((c) => walk(c, depth + 1));
      };
      walk(root, 0);
      return out.join('\\n');
    })()
    """

    /// Diagnostic probe: locates the composer and the empty-state greeting, which sit
    /// deeper than a bounded tree walk reaches.
    static let composerProbeJS = """
    (() => {
      const out = [];
      const d = (el) => {
        const r = el.getBoundingClientRect();
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 4).join('.')
          : '';
        return el.tagName.toLowerCase()
          + (el.id ? '#' + el.id : '')
          + (el.getAttribute('data-testid') ? '@' + el.getAttribute('data-testid') : '')
          + cls
          + ' ' + Math.round(r.width) + 'x' + Math.round(r.height)
          + '+' + Math.round(r.top);
      };

      out.push('--- composer: input then ancestors ---');
      let el = document.querySelector('[contenteditable="true"], textarea');
      let i = 0;
      while (el && i++ < 9) { out.push('  ' + d(el)); el = el.parentElement; }

      out.push('--- greeting / placeholder text holders ---');
      document.querySelectorAll('h1, h2, h3, p, span, div').forEach((e) => {
        const t = (e.textContent || '').trim();
        if (!t || t.length > 40) return;
        if (!/noodle|help you today|good |morning|evening|afternoon/i.test(t)) return;
        if (e.getBoundingClientRect().height < 8) return;
        if (out.length < 40) out.push('  ' + d(e) + ' "' + t.slice(0, 30) + '"');
      });

      out.push('--- svg logos above the composer ---');
      document.querySelectorAll('svg').forEach((e) => {
        const r = e.getBoundingClientRect();
        if (r.height >= 20 && r.height <= 80 && out.length < 55) {
          out.push('  ' + d(e) + ' parent=' + (e.parentElement ? d(e.parentElement) : '-'));
        }
      });
      return out.join('\\n');
    })()
    """

    /// Diagnostic probe: lists every `data-testid` on the page plus the ancestor
    /// chain of the composer's placeholder, to find stable hooks for the real
    /// composer box (`#static-composer` is a 0x0 pre-hydration placeholder).
    static let hooksProbeJS = """
    (() => {
      const out = [];
      const d = (el) => {
        const r = el.getBoundingClientRect();
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 4).join('.')
          : '';
        return el.tagName.toLowerCase()
          + (el.id ? '#' + el.id : '')
          + (el.getAttribute('data-testid') ? '@' + el.getAttribute('data-testid') : '')
          + cls
          + ' ' + Math.round(r.width) + 'x' + Math.round(r.height)
          + '+' + Math.round(r.top);
      };

      out.push('--- all data-testid ---');
      document.querySelectorAll('[data-testid]').forEach((e) => {
        if (out.length < 30) out.push('  ' + d(e));
      });

      out.push('--- visible editable fields ---');
      document.querySelectorAll('[contenteditable="true"], textarea, .ProseMirror')
        .forEach((e) => {
          const r = e.getBoundingClientRect();
          out.push('  ' + d(e) + (r.width < 2 ? ' (hidden)' : ' (VISIBLE)'));
        });

      out.push('--- ancestors of the placeholder ---');
      let target = null;
      document.querySelectorAll('div, span').forEach((e) => {
        const t = (e.textContent || '').trim();
        if (!target && /^How can I help you today/.test(t) && t.length < 40) target = e;
      });
      let i = 0;
      while (target && i++ < 9) { out.push('  ' + d(target)); target = target.parentElement; }
      return out.join('\\n');
    })()
    """

    /// Diagnostic probe: finds every element that paints a large opaque area, not
    /// just the ones on the `body` → `main` path. Anything listed here is blocking
    /// the window's translucency.
    static let opaqueProbeJS = """
    (() => {
      const vw = innerWidth, vh = innerHeight, out = [];
      const isClear = (bg) => {
        if (!bg || bg === 'transparent') return true;
        const m = bg.match(/rgba?\\(([^)]+)\\)/);
        if (m) {
          const parts = m[1].split(',').map((p) => parseFloat(p));
          return parts.length === 4 && parts[3] === 0;
        }
        return false;
      };
      document.querySelectorAll('*').forEach((el) => {
        const s = getComputedStyle(el);
        if (isClear(s.backgroundColor)) return;
        const r = el.getBoundingClientRect();
        // Only things big enough to be the backdrop itself.
        if (r.width * r.height < vw * vh * 0.2) return;
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 3).join('.')
          : '';
        out.push(el.tagName.toLowerCase()
          + (el.id ? '#' + el.id : '')
          + (el.getAttribute('data-testid') ? '@' + el.getAttribute('data-testid') : '')
          + cls
          + ' bg=' + s.backgroundColor
          + ' ' + Math.round(r.width) + 'x' + Math.round(r.height));
      });
      return out.length ? out.slice(0, 20).join('\\n') : 'no large opaque elements';
    })()
    """

    /// Reports the computed box of every ancestor above the composer.
    ///
    /// `getBoundingClientRect()` returns an element's own box even when an ancestor
    /// clips it to nothing, so a correct-looking rect can still be invisible. This
    /// shows which ancestor is doing the clipping.
    static let chainDiagJS = """
    (() => {
      const input = document.querySelector('[data-testid="chat-input"]');
      if (!input) return 'composer input not found';
      const box = input.closest('fieldset') || input;
      const out = [];
      let el = box, i = 0;
      while (el && i++ < 20) {
        const s = getComputedStyle(el);
        const r = el.getBoundingClientRect();
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 3).join('.')
          : '';
        out.push(i + ' ' + el.tagName.toLowerCase() + cls
          + ' rect=' + Math.round(r.width) + 'x' + Math.round(r.height)
          + '@' + Math.round(r.top)
          + ' client=' + el.clientWidth + 'x' + el.clientHeight
          + ' ' + s.display + ' vis=' + s.visibility + ' op=' + s.opacity
          + ' ovf=' + s.overflow + ' pos=' + s.position
          + ' h=' + s.height + ' flex=' + s.flex);
        el = el.parentElement;
      }
      return out.join('\\n');
    })()
    """

    /// Finds small visible elements floating outside the composer - leftover chrome
    /// that survives isolation because it lives above `main`.
    static let strayProbeJS = """
    (() => {
      const input = document.querySelector('[data-testid="chat-input"]');
      const box = input ? (input.closest('fieldset') || input) : null;
      const out = [];
      document.querySelectorAll('*').forEach((el) => {
        if (box && box.contains(el)) return;
        const r = el.getBoundingClientRect();
        if (r.width < 4 || r.height < 4 || r.width > 140 || r.height > 140) return;
        const s = getComputedStyle(el);
        if (s.display === 'none' || s.visibility === 'hidden' || s.opacity === '0') return;
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 3).join('.')
          : '';
        if (out.length < 18) {
          out.push(el.tagName.toLowerCase()
            + (el.id ? '#' + el.id : '')
            + (el.getAttribute('data-testid') ? '@' + el.getAttribute('data-testid') : '')
            + (el.getAttribute('aria-label') ? '~' + el.getAttribute('aria-label') : '')
            + cls
            + ' ' + Math.round(r.width) + 'x' + Math.round(r.height)
            + ' at ' + Math.round(r.left) + ',' + Math.round(r.top));
        }
      });
      return out.length ? out.join('\\n') : 'no stray elements';
    })()
    """

    /// Diagnostic probe: finds the chat-view chrome - notification banner, footer
    /// disclaimer, conversation header - with a few ancestors each, so the right
    /// container can be targeted rather than the leaf text node.
    static let chatChromeProbeJS = """
    (() => {
      const d = (el) => {
        const r = el.getBoundingClientRect();
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 3).join('.')
          : '';
        return el.tagName.toLowerCase()
          + (el.id ? '#' + el.id : '')
          + (el.getAttribute('data-testid') ? '@' + el.getAttribute('data-testid') : '')
          + (el.getAttribute('aria-label') ? '~' + el.getAttribute('aria-label') : '')
          + cls
          + ' ' + Math.round(r.width) + 'x' + Math.round(r.height) + '+' + Math.round(r.top);
      };
      const patterns = [
        ['notify banner', /want to be notified/i],
        ['footer disclaimer', /can make mistakes/i],
        ['share button', /^share$/i],
      ];
      const out = [];
      patterns.forEach(([label, re]) => {
        let deepest = null;
        document.querySelectorAll('div,span,button,p,section,header,aside').forEach((el) => {
          const t = (el.textContent || '').trim();
          if (t && t.length < 90 && re.test(t)) deepest = el;
        });
        out.push('--- ' + label + ' ---');
        if (!deepest) { out.push('  not found'); return; }
        let el = deepest, i = 0;
        while (el && i++ < 5) { out.push('  ' + d(el)); el = el.parentElement; }
      });
      out.push('--- header candidates ---');
      document.querySelectorAll('header').forEach((el) => {
        const r = el.getBoundingClientRect();
        if (r.height > 4) out.push('  ' + d(el));
      });
      return out.join('\\n');
    })()
    """

    /// Diagnostic probe: finds gradient scrims. claude.ai fades content out towards
    /// the composer with a gradient built for its own solid background, which over a
    /// translucent window reads as a heavy black band.
    static let gradientProbeJS = """
    (() => {
      const out = [];
      document.querySelectorAll('*').forEach((el) => {
        const s = getComputedStyle(el);
        // Pseudo-elements too: a fade is often drawn with `before:bg-gradient-*`,
        // which getComputedStyle(el) alone does not report.
        const before = getComputedStyle(el, '::before').backgroundImage;
        const after = getComputedStyle(el, '::after').backgroundImage;
        const bgs = [s.backgroundImage, before, after]
          .map((b, i) => ({ b, where: ['self', '::before', '::after'][i] }))
          .filter(({ b }) => b && b !== 'none' && /gradient/.test(b));
        if (!bgs.length) return;
        const bg = bgs.map(({ b, where }) => where + '=' + b.slice(0, 70)).join(' | ');
        const r = el.getBoundingClientRect();
        if (r.width < 80 || r.height < 20) return;
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 4).join('.')
          : '';
        if (out.length < 16) {
          out.push(el.tagName.toLowerCase()
            + (el.id ? '#' + el.id : '')
            + (el.getAttribute('data-testid') ? '@' + el.getAttribute('data-testid') : '')
            + cls
            + ' ' + Math.round(r.width) + 'x' + Math.round(r.height) + '+' + Math.round(r.top)
            + ' mask=' + (s.maskImage && s.maskImage !== 'none' ? 'yes' : 'no')
            + ' ' + bg);
        }
      });
      return out.length ? out.join('\\n') : 'no gradient elements';
    })()
    """

    /// Diagnostic probe: reports low-contrast text. claude.ai's muted greys are
    /// tuned for its own dark background and wash out over a translucent panel.
    static let mutedProbeJS = """
    (() => {
      const out = [];
      const luminance = (c) => {
        const m = c.match(/rgba?\\(([^)]+)\\)/);
        if (!m) return null;
        const [r, g, b] = m[1].split(',').map((p) => parseFloat(p));
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
      };
      document.querySelectorAll('main *').forEach((el) => {
        const text = Array.from(el.childNodes)
          .filter((n) => n.nodeType === 3)
          .map((n) => n.textContent.trim())
          .join(' ');
        if (!text || text.length > 70) return;
        const style = getComputedStyle(el);
        const lum = luminance(style.color);
        // Mid greys are the problem: too dark to read on the panel's own grey.
        if (lum === null || lum > 0.62) return;
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 4).join('.')
          : '';
        if (out.length < 14) {
          out.push(el.tagName.toLowerCase() + cls
            + ' color=' + style.color
            + ' lum=' + lum.toFixed(2)
            + ' "' + text.slice(0, 34) + '"');
        }
      });
      return out.length ? out.join('\\n') : 'no low-contrast text found';
    })()
    """

    /// Diagnostic probe: dumps the design tokens on :root, to find the variable
    /// behind the muted text colour rather than patching each class that uses it.
    static let tokenProbeJS = """
    (() => {
      const out = [];
      for (const sheet of document.styleSheets) {
        let rules;
        try { rules = sheet.cssRules; } catch (e) { continue; }
        for (const rule of rules) {
          if (!rule.style || !/:root|^html$/.test(rule.selectorText || '')) continue;
          for (const name of rule.style) {
            if (!name.startsWith('--')) continue;
            const value = rule.style.getPropertyValue(name).trim();
            if (!/text|muted|secondary|fg|foreground/i.test(name)) continue;
            if (out.length < 24) out.push(name + ' = ' + value);
          }
        }
      }
      const cs = getComputedStyle(document.documentElement);
      ['--text-300', '--text-400', '--text-muted', '--text-secondary'].forEach((n) => {
        const v = cs.getPropertyValue(n).trim();
        if (v) out.push('computed ' + n + ' = ' + v);
      });
      return out.length ? out.join('\\n') : 'no text tokens found';
    })()
    """

    /// Diagnostic probe: follows --text-400 from the muted element up its ancestors,
    /// to find which one is shadowing an override set on <html>.
    static let tokenChainProbeJS = """
    (() => {
      const out = [];
      out.push('stylesheet has override: '
        + /--text-400/.test(document.getElementById('claude-companion-style')?.textContent || ''));

      let target = null;
      document.querySelectorAll('main span').forEach((el) => {
        const t = (el.textContent || '').trim();
        if (!target && /^Thought for/.test(t)) target = el;
      });
      if (!target) return out.concat('no muted element found').join('\\n');

      out.push('muted element colour = ' + getComputedStyle(target).color);
      let el = target, i = 0;
      while (el && i++ < 12) {
        const value = getComputedStyle(el).getPropertyValue('--text-400').trim();
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 3).join('.')
          : '';
        out.push('  ' + el.tagName.toLowerCase() + cls + '  --text-400 = ' + (value || '(unset)'));
        el = el.parentElement;
      }
      return out.join('\\n');
    })()
    """

    /// Diagnostic probe: what governs Enter-to-send, and how the send control is
    /// identified, so the behaviour can be corrected at its source if possible.
    static let sendProbeJS = """
    (() => {
      const out = [];

      out.push('--- storage keys mentioning enter/send ---');
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (!/enter|send|compos|shortcut|keybind/i.test(key)) continue;
        const value = (localStorage.getItem(key) || '').slice(0, 120);
        if (out.length < 20) out.push('  ' + key + ' = ' + value);
      }
      if (out.length === 1) out.push('  (none)');

      out.push('--- send control ---');
      const candidates = document.querySelectorAll(
        'button[aria-label], button[type="submit"], [data-testid*="send"]');
      candidates.forEach((el) => {
        const label = el.getAttribute('aria-label') || el.getAttribute('data-testid') || '';
        if (!/send|submit/i.test(label)) return;
        const r = el.getBoundingClientRect();
        if (out.length < 34) {
          out.push('  ' + el.tagName.toLowerCase()
            + (el.getAttribute('data-testid') ? '@' + el.getAttribute('data-testid') : '')
            + ' aria="' + label + '"'
            + ' ' + Math.round(r.width) + 'x' + Math.round(r.height)
            + ' disabled=' + !!el.disabled);
        }
      });

      out.push('--- composer input ---');
      const input = document.querySelector('[data-testid="chat-input"]');
      if (input) {
        out.push('  ' + input.tagName.toLowerCase()
          + ' contenteditable=' + input.getAttribute('contenteditable')
          + ' enterkeyhint=' + (input.getAttribute('enterkeyhint') || '-'));
      } else {
        out.push('  (composer not found)');
      }
      return out.join('\\n');
    })()
    """

    /// Diagnostic probe: the composer's internal spacing - which element supplies the
    /// gap between the input row and the controls row, and how much.
    static let composerSpacingProbeJS = """
    (() => {
      const input = document.querySelector('[data-testid="chat-input"]');
      if (!input) return 'composer not found';
      const box = input.closest('fieldset') || input;
      const out = [];
      box.querySelectorAll('*').forEach((el) => {
        const cs = getComputedStyle(el);
        const gap = cs.rowGap && cs.rowGap !== 'normal' ? parseFloat(cs.rowGap) : 0;
        const mt = parseFloat(cs.marginTop) || 0;
        const mb = parseFloat(cs.marginBottom) || 0;
        const pt = parseFloat(cs.paddingTop) || 0;
        const pb = parseFloat(cs.paddingBottom) || 0;
        if (gap < 4 && mt < 4 && mb < 4 && pt < 4 && pb < 4) return;
        const r = el.getBoundingClientRect();
        if (r.height < 8) return;
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 4).join('.')
          : '';
        if (out.length < 12) {
          out.push(el.tagName.toLowerCase() + cls
            + ' ' + Math.round(r.width) + 'x' + Math.round(r.height)
            + ' gap=' + gap + ' margin=' + mt + '/' + mb
            + ' padding=' + pt + '/' + pb);
        }
      });
      const r = box.getBoundingClientRect();
      out.unshift('composer box = ' + Math.round(r.width) + 'x' + Math.round(r.height));
      return out.join('\\n');
    })()
    """

    /// Diagnostic probe: why the composer's input row is taller than its text.
    static let inputRowProbeJS = """
    (() => {
      const input = document.querySelector('[data-testid="chat-input"]');
      if (!input) return 'composer not found';
      const row = input.closest('div.overflow-y-auto') || input.parentElement;
      const out = [];
      const describe = (el, label) => {
        const cs = getComputedStyle(el);
        const r = el.getBoundingClientRect();
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 3).join('.')
          : '';
        out.push(label + el.tagName.toLowerCase() + cls
          + ' rect=' + Math.round(r.width) + 'x' + Math.round(r.height)
          + ' height=' + cs.height + ' min=' + cs.minHeight + ' max=' + cs.maxHeight
          + ' padding=' + cs.paddingTop + '/' + cs.paddingBottom
          + ' inline="' + (el.getAttribute('style') || '') + '"');
      };
      describe(row, 'row: ');
      Array.from(row.children).forEach((child) => describe(child, '  child: '));
      describe(input, '  input: ');
      Array.from(input.children).forEach((child, i) => {
        describe(child, '    editor child ' + i + ': ');
        const cs = getComputedStyle(child);
        out.push('      line-height=' + cs.lineHeight + ' margin=' + cs.marginTop
          + '/' + cs.marginBottom + ' text="' + (child.textContent || '').slice(0, 24) + '"');
      });
      return out.join('\\n');
    })()
    """

    /// Diagnostic probe: where the composer's horizontal space goes, from the text
    /// out to the window edge.
    static let horizontalProbeJS = """
    (() => {
      const input = document.querySelector('[data-testid="chat-input"]');
      if (!input) return 'composer not found';
      const out = ['viewport = ' + Math.round(innerWidth)];
      let el = input, i = 0;
      while (el && i++ < 16 && el.tagName !== 'MAIN') {
        const cs = getComputedStyle(el);
        const r = el.getBoundingClientRect();
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 3).join('.')
          : '';
        out.push('  ' + el.tagName.toLowerCase() + cls
          + ' width=' + Math.round(r.width)
          + ' left=' + Math.round(r.left) + ' right=' + Math.round(innerWidth - r.right)
          + ' margin=' + cs.marginLeft + '/' + cs.marginRight
          + ' padding=' + cs.paddingLeft + '/' + cs.paddingRight
          + ' maxw=' + cs.maxWidth);
        el = el.parentElement;
      }
      return out.join('\\n');
    })()
    """

    /// Verifies the injection actually took effect, rather than assuming it did.
    static let verifyJS = """
    (() => {
      const bodyBG = getComputedStyle(document.body).backgroundColor;
      const main = document.querySelector('main');
      const mainBG = main ? getComputedStyle(main).backgroundColor : 'no main';
      const sidebar = document.querySelector('[data-testid="sidebar"]');
      const sidebarDisplay = sidebar ? getComputedStyle(sidebar).display : 'absent';

      // Count anything still painting a large opaque area - the single most useful
      // signal that claude.ai has changed its markup and translucency has broken.
      const vw = innerWidth, vh = innerHeight;
      const isClear = (bg) => {
        if (!bg || bg === 'transparent') return true;
        const m = bg.match(/rgba?\\(([^)]+)\\)/);
        if (m) {
          const parts = m[1].split(',').map((p) => parseFloat(p));
          return parts.length === 4 && parts[3] === 0;
        }
        return false;
      };
      let opaque = 0;
      document.querySelectorAll('*').forEach((el) => {
        if (isClear(getComputedStyle(el).backgroundColor)) return;
        const r = el.getBoundingClientRect();
        if (r.width * r.height >= vw * vh * 0.2) opaque++;
      });

      // Composer geometry, to confirm compact mode isn't clipping it.
      const input = document.querySelector('[data-testid="chat-input"]');
      const box = input ? (input.closest('fieldset') || input) : null;
      let geom = ' composer=absent';
      if (box) {
        const r = box.getBoundingClientRect();
        geom = ' viewport=' + Math.round(innerHeight)
          + ' composer=' + Math.round(r.top) + '..' + Math.round(r.bottom)
          + (r.bottom > innerHeight + 1 ? ' CLIPPED' : ' fits');
      }

      const newChat = document.getElementById('cc-new-chat');
      let newChatState = 'absent';
      if (newChat) {
        const r = newChat.getBoundingClientRect();
        const cs = getComputedStyle(newChat);
        newChatState = Math.round(r.width) + 'x' + Math.round(r.height)
          + ' at ' + Math.round(r.left) + ',' + Math.round(r.top)
          + ' colour=' + cs.color + ' bg=' + cs.backgroundColor
          + (r.width > 0 && r.height > 0 && r.top >= 0 ? ' VISIBLE' : ' NOT VISIBLE');
      }

      return 'style injected=' + !!document.getElementById('claude-companion-style')
        + ' new-chat=' + newChatState
        + ' body bg=' + bodyBG
        + ' main bg=' + mainBG
        + ' sidebar display=' + sidebarDisplay
        + ' large-opaque-elements=' + opaque
        + ' compact=' + document.documentElement.classList.contains('cc-compact')
        + geom;
    })()
    """

    /// Diagnostic probe: reports the page's structural landmarks so the hiding
    /// rules below can target real selectors instead of guesses. claude.ai is a
    /// single-page app behind a login, so its DOM can only be inspected from
    /// inside an authenticated session like ours.
    static let probeJS = """
    (() => {
      const describe = (el) => {
        const r = el.getBoundingClientRect();
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 3).join('.')
          : '';
        return [
          el.tagName.toLowerCase(),
          el.id ? '#' + el.id : '',
          el.getAttribute('data-testid') ? '@' + el.getAttribute('data-testid') : '',
          el.getAttribute('aria-label') ? '~' + el.getAttribute('aria-label') : '',
          cls,
          Math.round(r.width) + 'x' + Math.round(r.height) + '@' + Math.round(r.left)
        ].filter(Boolean).join(' ');
      };
      const out = [];
      document.querySelectorAll('nav, aside, header, main, [data-testid], [role]')
        .forEach((el) => {
          const r = el.getBoundingClientRect();
          if (r.width > 60 && r.height > 60) out.push(describe(el));
        });
      return out.slice(0, 45).join('\\n');
    })()
    """

    /// Diagnostic probe: reports which elements paint an opaque background, so the
    /// transparency overrides know what to target.
    static let backgroundProbeJS = """
    (() => {
      const info = (el, prefix) => {
        const s = getComputedStyle(el);
        const r = el.getBoundingClientRect();
        const cls = typeof el.className === 'string' && el.className
          ? '.' + el.className.trim().split(/\\s+/).slice(0, 2).join('.')
          : '';
        const id = el.id ? '#' + el.id : '';
        const tid = el.getAttribute('data-testid') ? '@' + el.getAttribute('data-testid') : '';
        return prefix + el.tagName.toLowerCase() + id + tid + cls
          + ' bg=' + s.backgroundColor
          + ' ' + Math.round(r.width) + 'x' + Math.round(r.height);
      };
      const out = [info(document.documentElement, ''), info(document.body, '')];

      // Every ancestor between <body> and <main> can be painting a backdrop.
      let el = document.querySelector('main');
      const chain = [];
      while (el && el !== document.body) { chain.unshift(el); el = el.parentElement; }
      chain.forEach((e) => out.push(info(e, '  main-chain: ')));

      Array.from(document.body.children).forEach((e) => out.push(info(e, '  body-child: ')));
      return out.join('\\n');
    })()
    """
}
