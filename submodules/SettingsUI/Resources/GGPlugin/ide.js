(function () {
  const editor = byId("editor");
  const highlightLayer = byId("highlightLayer");
  const lineNumbers = byId("lineNumbers");
  const minimap = byId("minimap");
  const activeLine = byId("activeLine");
  const diagnostics = byId("diagnostics");
  const consoleEl = byId("console");
  const eventsEl = byId("events");
  const runtimeState = byId("runtimeState");
  const pluginName = byId("pluginName");
  const pluginMeta = byId("pluginMeta");
  const suggestions = byId("suggestions");
  const cursorStatus = byId("cursorStatus");
  const diagnosticStatus = byId("diagnosticStatus");
  const searchBar = byId("searchBar");
  const searchInput = byId("searchInput");
  const replaceInput = byId("replaceInput");
  const searchStatus = byId("searchStatus");
  const apiSearch = byId("apiSearch");
  const apiList = byId("apiList");
  const snippetList = byId("snippetList");
  const outlineList = byId("outlineList");
  const palette = byId("commandPalette");
  const paletteInput = byId("paletteInput");
  const paletteList = byId("paletteList");
  const manifestName = byId("manifestName");
  const manifestAuthor = byId("manifestAuthor");
  const manifestVersion = byId("manifestVersion");
  const manifestDescription = byId("manifestDescription");
  const sidebar = byId("sidebar");
  const sidebarBackdrop = byId("sidebarBackdrop");
  const sidebarClose = byId("sidebarClose");

  let state = {};
  let schema = { namespaces: [] };
  let changeTimer = null;
  let consoleFilter = "all";
  let currentDiagnostics = [];
  let currentSearchIndex = -1;
  let currentSuggestions = [];
  let suggestionIndex = 0;
  let suppressManifestWrite = false;
  let activeSidePanel = "explorer";

  const snippets = [
    {
      title: "Startup toast",
      text: "// @api 2\n// @permissions chat,messages,ui,events\n\nGGAPI.log(\"Plugin loaded\")\nGGAPI.toast(\"Plugin started\")"
    },
    {
      title: "Persistent counter",
      text: "const count = (GGAPI.storage.get(\"count\") || 0) + 1\nGGAPI.storage.set(\"count\", count)\nGGAPI.log({ count })"
    },
    {
      title: "Chat menu button",
      text: "GGAPI.ui.addChatMenuButton({ title: \"Ping\", icon: \"bolt\" }, () => {\n  GGAPI.toast(\"pong\")\n})"
    },
    {
      title: "Before send hook",
      text: "GGAPI.chat.onBeforeSend((payload) => {\n  GGAPI.log(payload)\n  return payload\n})"
    },
    {
      title: "Network fetch",
      text: "GGAPI.network.fetch(\"https://example.com\", { method: \"GET\" })\n  .then((response) => GGAPI.log(response.text))\n  .catch((error) => GGAPI.log(error.message))"
    },
    {
      title: "Floating action",
      text: "GGAPI.ui.addFloatingButton({ title: \"+\", color: \"#66e4ff\" }, () => {\n  GGAPI.chat.insertText(\"Hello from plugin\")\n})"
    },
    {
      title: "Plugin event bus",
      text: "GGAPI.plugins.on(\"plugin:test\", (event) => {\n  GGAPI.toast(\"from \" + event.sourcePluginId)\n  GGAPI.log(event.payload)\n})\n\nGGAPI.plugins.emit(\"plugin:test\", { hello: true })"
    },
    {
      title: "Engine deck",
      text: "// @api 2\n// @permissions chat,messages,media,ui,events,account\n\nGGAPI.events.on(\"chat.opened\", (chat) => {\n  GGAPI.ui.showToast(\"Chat \" + chat.peerId)\n})\n\nGGAPI.ui.addFloatingButton({ title: \"Deck\" }, () => {\n  const chat = GGAPI.chat.currentChatInfo()\n  GGAPI.chat.insertText(\"[deck:\" + chat.peerId + \"] \")\n})\n\nGGAPI.ui.addMessageContextAction({ title: \"Media info\" }, (payload) => {\n  const message = payload.message || GGAPI.messages.getSelectedMessage()\n  GGAPI.media.download(message.id).then((file) => {\n    GGAPI.log(file)\n    GGAPI.ui.showToast(file.available ? \"Downloaded\" : \"No media\")\n  })\n})"
    }
  ];

  const commands = [
    ["Save", () => runAction("save"), "Cmd S"],
    ["Run", () => runAction("run"), "Cmd Enter"],
    ["Stop", () => runAction("stop"), ""],
    ["Restart", () => runAction("restart"), ""],
    ["Format document", formatDocument, "Shift Alt F"],
    ["Open search", openSearch, "Cmd F"],
    ["Open GGAPI docs", () => post("openDocs"), ""],
    ["Insert startup template", () => insertSnippet(snippets[0].text), ""],
    ["Insert chat menu button", () => insertSnippet(snippets[2].text), ""],
    ["Duplicate plugin", () => runAction("duplicate"), ""],
    ["Delete plugin", () => runAction("delete"), ""]
  ];

  function byId(id) {
    return document.getElementById(id);
  }

  function post(type, payload) {
    const message = Object.assign({ type }, payload || {});
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ggplugin) {
      window.webkit.messageHandlers.ggplugin.postMessage(message);
    }
  }

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function updateAll() {
    updateManifestFromCode();
    renderHighlight();
    updateLines();
    updateCursor();
    renderOutline();
    renderDiagnostics(buildDiagnostics());
    renderMinimap();
  }

  function updateLines() {
    const count = Math.max(1, editor.value.split("\n").length);
    let lines = "";
    for (let i = 1; i <= count; i += 1) {
      lines += i + "\n";
    }
    lineNumbers.textContent = lines;
  }

  function renderHighlight() {
    const rows = editor.value.split("\n").map(tokenizeLine);
    highlightLayer.innerHTML = rows.join("\n") + "\n";
  }

  function tokenizeLine(line) {
    if (line.trim().startsWith("//")) {
      return `<span class="tok-comment">${escapeHtml(line)}</span>`;
    }
    let out = "";
    let i = 0;
    const keywords = new Set(["const", "let", "var", "function", "return", "if", "else", "for", "while", "class", "new", "try", "catch", "throw", "async", "await", "true", "false", "null", "undefined", "switch", "case", "break"]);
    while (i < line.length) {
      const ch = line[i];
      if (ch === "\"" || ch === "'" || ch === "`") {
        const quote = ch;
        let j = i + 1;
        while (j < line.length) {
          if (line[j] === "\\" && j + 1 < line.length) {
            j += 2;
            continue;
          }
          if (line[j] === quote) {
            j += 1;
            break;
          }
          j += 1;
        }
        out += `<span class="tok-string">${escapeHtml(line.slice(i, j))}</span>`;
        i = j;
      } else if (line.slice(i, i + 2) === "//") {
        out += `<span class="tok-comment">${escapeHtml(line.slice(i))}</span>`;
        break;
      } else if (/[0-9]/.test(ch)) {
        const match = line.slice(i).match(/^[0-9]+(\.[0-9]+)?/);
        out += `<span class="tok-number">${escapeHtml(match[0])}</span>`;
        i += match[0].length;
      } else if (/[A-Za-z_$]/.test(ch)) {
        const match = line.slice(i).match(/^[A-Za-z_$][A-Za-z0-9_$]*/);
        const word = match[0];
        const next = line.slice(i + word.length).trimStart()[0];
        if (word === "GGAPI" || word === "GG") {
          out += `<span class="tok-ggapi">${word}</span>`;
        } else if (keywords.has(word)) {
          out += `<span class="tok-keyword">${word}</span>`;
        } else if (next === "(") {
          out += `<span class="tok-function">${word}</span>`;
        } else {
          out += escapeHtml(word);
        }
        i += word.length;
      } else if (/[\+\-\*\/=%!<>&|?:]/.test(ch)) {
        out += `<span class="tok-operator">${escapeHtml(ch)}</span>`;
        i += 1;
      } else {
        out += escapeHtml(ch);
        i += 1;
      }
    }
    return out || " ";
  }

  function buildDiagnostics() {
    const items = syntaxDiagnostics(editor.value);
    const runtime = state.runtime || {};
    if (runtime.error && runtime.error.message) {
      items.push({
        type: "runtime",
        message: runtime.error.message,
        line: runtime.error.line || null,
        column: runtime.error.column || null,
        stack: runtime.error.stack || ""
      });
    }
    return items;
  }

  function syntaxDiagnostics(code) {
    try {
      new Function(code);
      return [];
    } catch (error) {
      const parsed = parseErrorPosition(error);
      return [{
        type: "syntax",
        message: error.message || String(error),
        stack: error.stack || "",
        line: parsed.line,
        column: parsed.column
      }];
    }
  }

  function parseErrorPosition(error) {
    const stack = error && error.stack ? String(error.stack) : "";
    const match = stack.match(/<anonymous>:(\d+):(\d+)/) || stack.match(/Function:(\d+):(\d+)/);
    if (!match) {
      return { line: null, column: null };
    }
    return { line: Math.max(1, Number(match[1]) - 2), column: Number(match[2]) };
  }

  function renderDiagnostics(items) {
    currentDiagnostics = items || [];
    const activeClass = diagnostics.classList.contains("active") ? " active" : "";
    diagnosticStatus.textContent = `${currentDiagnostics.length} diagnostics`;
    if (!currentDiagnostics.length) {
      diagnostics.className = `workbenchPanel${activeClass} muted`;
      diagnostics.textContent = "No issues";
      post("diagnosticsChanged", { diagnostics: [] });
      return;
    }
    diagnostics.className = `workbenchPanel${activeClass}`;
    diagnostics.innerHTML = currentDiagnostics.map((item, index) => {
      const pos = item.line ? `Ln ${item.line}${item.column ? `, Col ${item.column}` : ""}` : "Global";
      return `<div class="diagnosticItem" data-diagnostic="${index}">
        <div class="diagnosticPos">${escapeHtml(pos)}</div>
        <div class="${item.type === "runtime" ? "error" : "warn"}">${escapeHtml(item.message || "")}</div>
      </div>`;
    }).join("");
    post("diagnosticsChanged", { diagnostics: currentDiagnostics });
  }

  function renderConsole(lines) {
    const filtered = (lines || []).filter((line) => consoleFilter === "all" || line.level === consoleFilter);
    consoleEl.innerHTML = filtered.map((line) => {
      const level = line.level || "log";
      return `<div class="consoleLine ${escapeHtml(level)}">[${escapeHtml(level)}] ${escapeHtml(line.text || "")}</div>`;
    }).join("");
    consoleEl.scrollTop = consoleEl.scrollHeight;
  }

  function renderEvents() {
    const runtime = state.runtime || {};
    const debug = state.debug || {};
    const ui = debug.ui || {};
    const rows = [
      ["Runtime", runtime.state || "stopped"],
      ["Plugin", (state.plugin || {}).id || ""],
      ["Console lines", ((state.console || []).length).toString()],
      ["GGAPI namespaces", ((schema.namespaces || []).length).toString()],
      ["Active plugins", ((debug.activePlugins || []).filter((item) => item.running).length).toString()],
      ["UI registrations", Object.keys(ui).reduce((sum, key) => sum + ((ui[key] || []).length), 0).toString()]
    ];
    const eventRows = (debug.lastEvents || []).slice(-8).reverse().map((event) => [
      event.kind || "event",
      `${event.channel || ""} ${event.sourcePluginId ? "(" + event.sourcePluginId + ")" : ""}`
    ]);
    eventsEl.innerHTML = rows.concat(eventRows).map(([key, value]) => `<div class="consoleLine"><span class="muted">${escapeHtml(key)}:</span> ${escapeHtml(value)}</div>`).join("");
  }

  function updateCursor() {
    const pos = editor.selectionStart;
    const before = editor.value.slice(0, pos);
    const line = before.split("\n").length;
    const col = before.length - before.lastIndexOf("\n");
    cursorStatus.textContent = `Ln ${line}, Col ${col}`;
    const lineHeight = editorLineHeight();
    const paddingTop = parseFloat(getComputedStyle(editor).paddingTop) || 0;
    activeLine.style.top = `${(line - 1) * lineHeight + paddingTop - editor.scrollTop}px`;
  }

  function editorLineHeight() {
    return parseFloat(getComputedStyle(editor).lineHeight) || 21;
  }

  function renderMinimap() {
    minimap.textContent = editor.value.split("\n").map((line) => {
      const compact = line.trim().replace(/\s+/g, " ");
      return compact.slice(0, 80) || " ";
    }).join("\n");
  }

  function renderOutline() {
    const symbols = [];
    editor.value.split("\n").forEach((line, index) => {
      const fn = line.match(/^\s*(?:async\s+)?function\s+([A-Za-z_$][A-Za-z0-9_$]*)/) || line.match(/^\s*(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*(?:async\s*)?\(/);
      if (fn) {
        symbols.push({ name: fn[1], line: index + 1 });
      }
    });
    if (!symbols.length) {
      outlineList.className = "outlineList muted";
      outlineList.textContent = "No symbols";
      return;
    }
    outlineList.className = "outlineList";
    outlineList.innerHTML = symbols.map((symbol) => `<button class="outlineItem" data-line="${symbol.line}">${escapeHtml(symbol.name)} · ${symbol.line}</button>`).join("");
  }

  function updateManifestFromCode() {
    const manifest = parseManifest(editor.value);
    suppressManifestWrite = true;
    manifestName.value = manifest.name || (state.plugin || {}).name || "";
    manifestAuthor.value = manifest.author || (state.plugin || {}).author || "";
    manifestVersion.value = manifest.version || (state.plugin || {}).version || "";
    manifestDescription.value = manifest.description || (state.plugin || {}).description || "";
    suppressManifestWrite = false;
  }

  function parseManifest(code) {
    const result = {};
    for (const raw of code.split("\n")) {
      const line = raw.trim();
      if (!line) {
        continue;
      }
      const match = line.match(/^\/\/\s*@([a-zA-Z]+)\s*(.*)$/);
      if (!match) {
        break;
      }
      const key = match[1].toLowerCase();
      if (key === "description") {
        result.description = match[2] || "";
      } else {
        result[key] = match[2] || "";
      }
    }
    return result;
  }

  function writeManifestToCode() {
    if (suppressManifestWrite) {
      return;
    }
    const fields = [
      ["name", manifestName.value || "New Plugin"],
      ["author", manifestAuthor.value || ""],
      ["description", manifestDescription.value || ""],
      ["version", manifestVersion.value || "1.0.0"]
    ];
    const lines = editor.value.split("\n");
    let start = 0;
    while (start < lines.length && (lines[start].trim() === "" || lines[start].trim().startsWith("// @"))) {
      start += 1;
    }
    const header = fields.map(([key, value]) => `// @${key} ${value}`);
    editor.value = header.concat([""], lines.slice(start)).join("\n");
    notifyCodeChanged();
    updateAll();
  }

  function renderApiList(filter) {
    const query = (filter || "").toLowerCase();
    const groups = [];
    (schema.namespaces || []).forEach((namespace) => {
      const cards = [];
      (namespace.methods || []).forEach((method) => {
        const signature = `GGAPI.${namespace.name}.${method.signature}`;
        const searchable = [signature, method.example || "", method.description || "", method.availability || ""].join(" ").toLowerCase();
        if (query && !searchable.includes(query)) {
          return;
        }
        const availability = method.availableNow === false ? "bridge" : (method.availability || "available");
        cards.push(`<div class="apiCard ${method.availableNow === false ? "bridgeOnly" : ""}">
          <div class="apiName">${escapeHtml(signature)} <span class="apiBadge">${escapeHtml(availability)}</span></div>
          <div class="apiExample">${escapeHtml(method.example || "")}</div>
          <button class="apiInsert" data-insert="${escapeHtml(signature)}">Insert</button>
        </div>`);
      });
      if (cards.length) {
        groups.push(`<div class="apiGroup">
          <div class="apiGroupTitle">${escapeHtml(namespace.name)} <span>${escapeHtml(namespace.description || "")}</span></div>
          ${cards.join("")}
        </div>`);
      }
    });
    apiList.innerHTML = groups.join("") || `<div class="muted">No API matches</div>`;
  }

  function renderSnippets() {
    snippetList.innerHTML = snippets.map((snippet, index) => `<div class="snippetCard">
      <div class="snippetTitle">${escapeHtml(snippet.title)}</div>
      <div class="snippetText">${escapeHtml(snippet.text.split("\n")[0])}</div>
      <button class="snippetButton" data-snippet="${index}">Insert snippet</button>
    </div>`).join("");
  }

  function flattenMethods() {
    const result = [];
    (schema.namespaces || []).forEach((namespace) => {
      (namespace.methods || []).forEach((method) => {
        result.push({
          label: `GGAPI.${namespace.name}.${method.signature}`,
          insert: `GGAPI.${namespace.name}.${method.signature.replace(/\([^)]*\)/, "(")}`,
          help: method.example || namespace.description || ""
        });
      });
    });
    result.push({ label: "GGAPI.log(value)", insert: "GGAPI.log(", help: "Write to plugin console" });
    result.push({ label: "const GG = GGAPI", insert: "const GG = GGAPI", help: "Short alias" });
    return result;
  }

  function currentToken() {
    const pos = editor.selectionStart;
    const left = editor.value.slice(0, pos);
    const match = left.match(/[A-Za-z0-9_.$]+$/);
    return match ? match[0] : "";
  }

  function showSuggestions() {
    const token = currentToken().toLowerCase();
    currentSuggestions = flattenMethods().filter((item) => !token || item.label.toLowerCase().includes(token)).slice(0, 14);
    suggestionIndex = Math.max(0, Math.min(suggestionIndex, currentSuggestions.length - 1));
    if (!currentSuggestions.length) {
      suggestions.classList.add("hidden");
      return;
    }
    renderSuggestions();
  }

  function renderSuggestions() {
    suggestions.innerHTML = currentSuggestions.map((item, index) => `<div class="suggestion ${index === suggestionIndex ? "active" : ""}" data-suggestion="${index}">
      <div>${escapeHtml(item.label)}</div>
      <div class="suggestionHelp">${escapeHtml(item.help)}</div>
    </div>`).join("");
    const rect = caretApproxRect();
    suggestions.style.left = `${Math.min(rect.left, window.innerWidth - 460)}px`;
    suggestions.style.top = `${Math.min(rect.top + 24, window.innerHeight - 310)}px`;
    suggestions.classList.remove("hidden");
  }

  function isMobileLayout() {
    return window.matchMedia("(max-width: 760px)").matches;
  }

  function openSidePanel(panel) {
    activeSidePanel = panel;
    document.querySelectorAll(".activityButton").forEach((item) => item.classList.toggle("active", item.getAttribute("data-panel") === panel));
    document.querySelectorAll(".sidePanel").forEach((item) => item.classList.toggle("active", item.getAttribute("data-panel-view") === panel));
    if (isMobileLayout()) {
      sidebar.classList.add("open");
      sidebarBackdrop.classList.remove("hidden");
    }
  }

  function closeSidePanel() {
    sidebar.classList.remove("open");
    sidebarBackdrop.classList.add("hidden");
    editor.focus();
  }

  function caretApproxRect() {
    const before = editor.value.slice(0, editor.selectionStart);
    const lines = before.split("\n");
    const line = lines.length;
    const col = lines[lines.length - 1].length;
    const editorRect = editor.getBoundingClientRect();
    const style = getComputedStyle(editor);
    const paddingLeft = parseFloat(style.paddingLeft) || 0;
    const paddingTop = parseFloat(style.paddingTop) || 0;
    return {
      left: editorRect.left + paddingLeft + Math.min(col * 7.8, editorRect.width - 60),
      top: editorRect.top + paddingTop + (line - 1) * editorLineHeight() - editor.scrollTop
    };
  }

  function acceptSuggestion(index) {
    const item = currentSuggestions[index];
    if (!item) {
      return;
    }
    const token = currentToken();
    const end = editor.selectionStart;
    const start = end - token.length;
    editor.setSelectionRange(start, end);
    editor.setRangeText(item.insert, start, end, "end");
    suggestions.classList.add("hidden");
    notifyCodeChanged();
    updateAll();
    editor.focus();
  }

  function notifyCodeChanged() {
    clearTimeout(changeTimer);
    changeTimer = setTimeout(() => post("codeChanged", { code: editor.value }), 80);
  }

  function runAction(action) {
    post("codeChanged", { code: editor.value });
    if (action === "docs") {
      post("openDocs");
    } else {
      post(action);
    }
  }

  function insertSnippet(text) {
    const start = editor.selectionStart;
    editor.setRangeText(text, start, editor.selectionEnd, "end");
    notifyCodeChanged();
    updateAll();
    editor.focus();
  }

  function formatDocument() {
    const lines = editor.value.split("\n");
    let indent = 0;
    const formatted = lines.map((raw) => {
      const line = raw.trim();
      if (!line) {
        return "";
      }
      if (/^[}\])]/.test(line)) {
        indent = Math.max(0, indent - 1);
      }
      const result = "  ".repeat(indent) + line;
      const opens = (line.match(/[{\[(]/g) || []).length;
      const closes = (line.match(/[}\])]/g) || []).length;
      if (opens > closes && !line.startsWith("//")) {
        indent += 1;
      }
      if (line.endsWith("};") || line.endsWith("})")) {
        indent = Math.max(0, indent);
      }
      return result;
    });
    editor.value = formatted.join("\n");
    notifyCodeChanged();
    updateAll();
  }

  function openSearch() {
    searchBar.classList.remove("hidden");
    searchInput.focus();
    searchInput.select();
    updateSearchStatus();
  }

  function closeSearch() {
    searchBar.classList.add("hidden");
    editor.focus();
  }

  function searchMatches() {
    const query = searchInput.value;
    if (!query) {
      return [];
    }
    const matches = [];
    let index = editor.value.indexOf(query);
    while (index !== -1) {
      matches.push(index);
      index = editor.value.indexOf(query, index + query.length);
    }
    return matches;
  }

  function updateSearchStatus() {
    const matches = searchMatches();
    searchStatus.textContent = matches.length ? `${Math.max(1, currentSearchIndex + 1)} / ${matches.length}` : "0 / 0";
  }

  function findNext(direction) {
    const matches = searchMatches();
    if (!matches.length) {
      currentSearchIndex = -1;
      updateSearchStatus();
      return;
    }
    currentSearchIndex = (currentSearchIndex + direction + matches.length) % matches.length;
    const start = matches[currentSearchIndex];
    editor.focus();
    editor.setSelectionRange(start, start + searchInput.value.length);
    updateSearchStatus();
  }

  function replaceOne() {
    if (editor.selectionStart !== editor.selectionEnd && editor.value.slice(editor.selectionStart, editor.selectionEnd) === searchInput.value) {
      editor.setRangeText(replaceInput.value, editor.selectionStart, editor.selectionEnd, "end");
      notifyCodeChanged();
      updateAll();
    }
    findNext(1);
  }

  function replaceAll() {
    const query = searchInput.value;
    if (!query) {
      return;
    }
    editor.value = editor.value.split(query).join(replaceInput.value);
    currentSearchIndex = -1;
    notifyCodeChanged();
    updateAll();
    updateSearchStatus();
  }

  function gotoLine(line) {
    const lines = editor.value.split("\n");
    let pos = 0;
    for (let i = 0; i < Math.max(0, line - 1); i += 1) {
      pos += lines[i].length + 1;
    }
    editor.focus();
    editor.setSelectionRange(pos, pos);
    editor.scrollTop = Math.max(0, (line - 4) * editorLineHeight());
    syncScroll();
    updateCursor();
  }

  function openPalette() {
    palette.classList.remove("hidden");
    paletteInput.value = "";
    renderPalette("");
    paletteInput.focus();
  }

  function closePalette() {
    palette.classList.add("hidden");
    editor.focus();
  }

  function renderPalette(query) {
    const q = (query || "").toLowerCase();
    const filtered = commands.filter(([name]) => name.toLowerCase().includes(q));
    paletteList.innerHTML = filtered.map(([name, _, shortcut], index) => `<div class="paletteItem ${index === 0 ? "active" : ""}" data-command-index="${commands.findIndex((command) => command[0] === name)}">
      ${escapeHtml(name)} <span class="muted">${escapeHtml(shortcut)}</span>
    </div>`).join("");
  }

  function syncScroll() {
    highlightLayer.scrollTop = editor.scrollTop;
    highlightLayer.scrollLeft = editor.scrollLeft;
    lineNumbers.scrollTop = editor.scrollTop;
    minimap.scrollTop = editor.scrollTop / 5;
    updateCursor();
  }

  function renderState(next) {
    state = next || {};
    schema = state.schema || schema;
    const plugin = state.plugin || {};
    if (typeof plugin.code === "string" && editor.value !== plugin.code && document.activeElement !== editor) {
      editor.value = plugin.code;
    }
    pluginName.textContent = plugin.name || "GGPlugin";
    pluginMeta.textContent = [plugin.author, plugin.version, plugin.description].filter(Boolean).join(" · ");
    const runtime = state.runtime || {};
    runtimeState.textContent = runtime.state || "stopped";
    runtimeState.className = "runtimeState " + (runtime.state || "stopped");
    renderApiList(apiSearch.value);
    renderSnippets();
    renderConsole(state.console || []);
    renderEvents();
    updateAll();
  }

  editor.addEventListener("input", () => {
    notifyCodeChanged();
    updateAll();
    const token = currentToken();
    if (token.includes("GGAPI") || token.includes("GG.")) {
      suggestionIndex = 0;
      showSuggestions();
    } else {
      suggestions.classList.add("hidden");
    }
  });

  editor.addEventListener("scroll", syncScroll);
  editor.addEventListener("click", updateCursor);
  editor.addEventListener("keyup", updateCursor);

  editor.addEventListener("keydown", (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "s") {
      event.preventDefault();
      runAction("save");
      return;
    }
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault();
      runAction("run");
      return;
    }
    if ((event.metaKey || event.ctrlKey) && event.shiftKey && event.key.toLowerCase() === "p") {
      event.preventDefault();
      openPalette();
      return;
    }
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "f") {
      event.preventDefault();
      openSearch();
      return;
    }
    if (event.altKey && event.shiftKey && event.key.toLowerCase() === "f") {
      event.preventDefault();
      formatDocument();
      return;
    }
    if ((event.metaKey || event.ctrlKey) && event.key === " ") {
      event.preventDefault();
      showSuggestions();
      return;
    }
    if (!suggestions.classList.contains("hidden")) {
      if (event.key === "ArrowDown") {
        event.preventDefault();
        suggestionIndex = Math.min(currentSuggestions.length - 1, suggestionIndex + 1);
        renderSuggestions();
        return;
      }
      if (event.key === "ArrowUp") {
        event.preventDefault();
        suggestionIndex = Math.max(0, suggestionIndex - 1);
        renderSuggestions();
        return;
      }
      if (event.key === "Enter" || event.key === "Tab") {
        event.preventDefault();
        acceptSuggestion(suggestionIndex);
        return;
      }
    }
    if (event.key === "Tab") {
      event.preventDefault();
      editor.setRangeText("  ", editor.selectionStart, editor.selectionEnd, "end");
      notifyCodeChanged();
      updateAll();
      return;
    }
    const pairs = { "(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'" };
    if (pairs[event.key]) {
      event.preventDefault();
      const start = editor.selectionStart;
      const selected = editor.value.slice(editor.selectionStart, editor.selectionEnd);
      editor.setRangeText(event.key + selected + pairs[event.key], editor.selectionStart, editor.selectionEnd, selected ? "select" : "end");
      if (!selected) {
        editor.setSelectionRange(start + 1, start + 1);
      }
      notifyCodeChanged();
      updateAll();
      return;
    }
    if (event.key === "Escape") {
      suggestions.classList.add("hidden");
    }
  });

  document.querySelectorAll("[data-action]").forEach((button) => {
    button.addEventListener("click", () => runAction(button.getAttribute("data-action")));
  });

  document.querySelectorAll("[data-command]").forEach((button) => {
    button.addEventListener("click", () => {
      const command = button.getAttribute("data-command");
      if (command === "palette") openPalette();
      if (command === "search") openSearch();
      if (command === "format") formatDocument();
      if (command === "findPrev") findNext(-1);
      if (command === "findNext") findNext(1);
      if (command === "replaceOne") replaceOne();
      if (command === "replaceAll") replaceAll();
      if (command === "closeSearch") closeSearch();
    });
  });

  document.querySelectorAll(".activityButton").forEach((button) => {
    button.addEventListener("click", () => {
      openSidePanel(button.getAttribute("data-panel"));
    });
  });

  sidebarClose.addEventListener("click", closeSidePanel);
  sidebarBackdrop.addEventListener("click", closeSidePanel);

  document.querySelectorAll(".workbenchTab").forEach((button) => {
    button.addEventListener("click", () => {
      const tab = button.getAttribute("data-bottom");
      const workbench = button.closest(".bottomWorkbench");
      let shouldCollapse = false;
      if (isMobileLayout() && button.classList.contains("active") && workbench.classList.contains("expanded")) {
        shouldCollapse = true;
      }
      document.querySelectorAll(".workbenchTab").forEach((item) => item.classList.toggle("active", item === button));
      document.querySelectorAll(".workbenchPanel").forEach((item) => item.classList.toggle("active", item.getAttribute("data-bottom-view") === tab));
      if (isMobileLayout()) {
        workbench.classList.toggle("expanded", !shouldCollapse);
      }
    });
  });

  document.querySelectorAll("[data-console-filter]").forEach((button) => {
    button.addEventListener("click", () => {
      consoleFilter = button.getAttribute("data-console-filter");
      document.querySelectorAll("[data-console-filter]").forEach((item) => item.classList.toggle("active", item === button));
      renderConsole(state.console || []);
    });
  });

  diagnostics.addEventListener("click", (event) => {
    const row = event.target.closest("[data-diagnostic]");
    if (!row) {
      return;
    }
    const item = currentDiagnostics[Number(row.getAttribute("data-diagnostic"))];
    if (item && item.line) {
      gotoLine(item.line);
    }
  });

  outlineList.addEventListener("click", (event) => {
    const row = event.target.closest("[data-line]");
    if (row) {
      gotoLine(Number(row.getAttribute("data-line")));
    }
  });

  apiList.addEventListener("click", (event) => {
    const button = event.target.closest("[data-insert]");
    if (button) {
      insertSnippet(button.getAttribute("data-insert"));
    }
  });

  snippetList.addEventListener("click", (event) => {
    const button = event.target.closest("[data-snippet]");
    if (button) {
      insertSnippet(snippets[Number(button.getAttribute("data-snippet"))].text);
    }
  });

  suggestions.addEventListener("click", (event) => {
    const row = event.target.closest("[data-suggestion]");
    if (row) {
      acceptSuggestion(Number(row.getAttribute("data-suggestion")));
    }
  });

  apiSearch.addEventListener("input", () => renderApiList(apiSearch.value));
  searchInput.addEventListener("input", () => {
    currentSearchIndex = -1;
    updateSearchStatus();
  });

  [manifestName, manifestAuthor, manifestVersion, manifestDescription].forEach((field) => {
    field.addEventListener("change", writeManifestToCode);
  });

  paletteInput.addEventListener("input", () => renderPalette(paletteInput.value));
  paletteInput.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closePalette();
    }
    if (event.key === "Enter") {
      const active = paletteList.querySelector(".paletteItem.active") || paletteList.querySelector(".paletteItem");
      if (active) {
        const command = commands[Number(active.getAttribute("data-command-index"))];
        closePalette();
        command[1]();
      }
    }
  });

  paletteList.addEventListener("click", (event) => {
    const item = event.target.closest("[data-command-index]");
    if (!item) {
      return;
    }
    const command = commands[Number(item.getAttribute("data-command-index"))];
    closePalette();
    command[1]();
  });

  palette.addEventListener("click", (event) => {
    if (event.target === palette) {
      closePalette();
    }
  });

  window.GGPluginIDE = {
    setState: renderState
  };

  window.addEventListener("resize", () => {
    if (!isMobileLayout()) {
      sidebar.classList.remove("open");
      sidebarBackdrop.classList.add("hidden");
      openSidePanel(activeSidePanel);
    }
    updateCursor();
  });

  renderSnippets();
  renderPalette("");
  updateAll();
  post("ready");
})();
