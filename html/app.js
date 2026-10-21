(() => {
    "use strict";

    const RES = typeof GetParentResourceName === "function" ? GetParentResourceName() : "fks-character";
    const $ = (sel, root = document) => root.querySelector(sel);
    const el = (tag, cls, text) => {
        const e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text !== undefined && text !== null) e.textContent = text;
        return e;
    };
    const svgUse = (id, cls = "") => {
        const ns = "http://www.w3.org/2000/svg";
        const s = document.createElementNS(ns, "svg");
        if (cls) s.setAttribute("class", cls);
        const u = document.createElementNS(ns, "use");
        u.setAttribute("href", `#${id}`);
        s.appendChild(u);
        return s;
    };

    const state = {
        locale: {},
        mode: null,     // "sel" | "cr"
        sel: null,
        selected: null,
        cr: null,       // { tabs, values, counts, model, identity }
        tab: "identity",
        form: null,
        spawn: null,
        busy: false,
    };

    // ------------------------------------------------------------------
    //  Utilidades
    // ------------------------------------------------------------------

    function t(key, ...args) {
        let s = state.locale[key] || key;
        args.forEach(a => { s = s.replace("%s", a); });
        return s;
    }

    async function post(name, data = {}) {
        try {
            const r = await fetch(`https://${RES}/${name}`, {
                method: "POST",
                headers: { "Content-Type": "application/json; charset=UTF-8" },
                body: JSON.stringify(data),
            });
            return await r.json();
        } catch (e) {
            return { ok: false };
        }
    }

    function toast(text, type = "info") {
        const n = el("div", `toast ${type}`, text);
        $("#toasts").appendChild(n);
        setTimeout(() => n.classList.add("out"), 3800);
        setTimeout(() => n.remove(), 4200);
    }

    function handleResult(res) {
        if (res && res.ok === false && (res.message || res.error)) toast(res.message || t(res.error), "error");
        return res;
    }

    function translateStatic() {
        document.querySelectorAll("[data-t]").forEach(n => { n.textContent = t(n.dataset.t); });
    }

    function show(sel, on) { $(sel).classList.toggle("hidden", !on); }

    function setLoading(data) {
        if (data) {
            $("#loading-text").textContent = data.text || "";
            show("#loading", true);
        } else {
            show("#loading", false);
        }
    }

    const throttles = {};
    function throttled(key, fn, ms = 60) {
        const now = performance.now();
        const th = throttles[key] || (throttles[key] = { last: 0, timer: null });
        clearTimeout(th.timer);
        if (now - th.last >= ms) {
            th.last = now;
            fn();
        } else {
            th.timer = setTimeout(() => { th.last = performance.now(); fn(); }, ms);
        }
    }

    const fmtMoney = v => "$" + (Number(v) || 0).toFixed(2);
    function fmtDate(iso) {
        if (!iso) return "";
        const [y, m, d] = iso.split("-");
        return `${d}/${m}/${y}`;
    }

    function setHead(eyebrow, title) {
        $("#eyebrow-text").textContent = eyebrow;
        $("#title").textContent = title;
    }

    // target: "#hints" (rodapé, seleção) ou "#cam-hints" (por baixo dos controlos da câmara)
    function setHints(pairs, target = "#hints") {
        $("#hints").innerHTML = "";
        $("#cam-hints").innerHTML = "";
        const h = $(target);
        pairs.forEach(([key, label], i) => {
            if (i) h.appendChild(document.createElement("br"));
            h.append(label + " ");
            h.appendChild(el("kbd", "", key));
        });
    }

    function animateView() {
        const v = $("#view");
        v.classList.remove("view-in");
        void v.offsetWidth;
        v.classList.add("view-in");
    }

    // ------------------------------------------------------------------
    //  Modal
    // ------------------------------------------------------------------

    let modal = null;
    function openModal({ title, body, okText, danger = false, onConfirm, canConfirm }) {
        $("#modal-title").textContent = title;
        const b = $("#modal-body");
        b.innerHTML = "";
        b.appendChild(body);
        const ok = $("#modal-ok");
        ok.textContent = okText || t("confirm");
        ok.className = `btn ${danger ? "danger" : ""}`;
        ok.disabled = canConfirm ? !canConfirm() : false;
        modal = { onConfirm, canConfirm };
        show("#modal", true);
        const input = b.querySelector("input");
        if (input) setTimeout(() => input.focus(), 50);
    }
    function closeModal() { show("#modal", false); modal = null; }
    function refreshModal() {
        if (modal && modal.canConfirm) $("#modal-ok").disabled = !modal.canConfirm();
    }

    $("#modal-cancel").addEventListener("click", closeModal);
    $("#modal-ok").addEventListener("click", async () => {
        if (!modal || $("#modal-ok").disabled) return;
        const fn = modal.onConfirm;
        $("#modal-ok").disabled = true;
        const keep = await fn();
        if (!keep) closeModal(); else refreshModal();
    });

    // ------------------------------------------------------------------
    //  Palco: rodar / zoom com o rato e teclado
    // ------------------------------------------------------------------

    const stage = $("#stage");
    let drag = null;
    stage.addEventListener("mousedown", e => {
        drag = { x: e.clientX, acc: 0 };
        stage.classList.add("drag");
    });
    window.addEventListener("mouseup", () => { drag = null; stage.classList.remove("drag"); });
    window.addEventListener("mousemove", e => {
        if (!drag) return;
        drag.acc += (e.clientX - drag.x) * 0.45;
        drag.x = e.clientX;
        throttled("rotate", () => {
            if (!drag || Math.abs(drag.acc) < 0.5) return;
            post("cam:rotate", { deg: drag.acc });
            drag.acc = 0;
        }, 40);
    });
    stage.addEventListener("wheel", e => {
        throttled("zoom", () => post("cam:zoom", { dir: e.deltaY > 0 ? 1 : -1 }), 50);
    });

    // Escolha de género na cutscene: TAB / setas / A-D alternam, ENTER / espaço escolhem, rato também
    document.querySelectorAll(".choose-opts span").forEach(s => {
        s.addEventListener("mouseenter", () => { if (state.choosing && !s.classList.contains("on")) post("intro:select", { model: s.dataset.model }); });
        s.addEventListener("click", () => { if (state.choosing) post("intro:select", { model: s.dataset.model }).then(() => post("intro:confirm")); });
    });
    window.addEventListener("keydown", e => {
        if (!state.choosing) return;
        const k = e.key.toLowerCase();
        if (k === "tab" || k === "arrowleft" || k === "arrowright" || k === "a" || k === "d") {
            e.preventDefault();
            post("intro:toggle");
        } else if (k === "enter" || k === " ") {
            e.preventDefault();
            post("intro:confirm");
        }
    }, true);

    window.addEventListener("keydown", e => {
        if (state.choosing) return;
        const typing = ["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement && document.activeElement.tagName);
        if (e.key === "Escape" && modal) return closeModal();
        if (typing || modal || !state.mode) return;
        const k = e.key.toLowerCase();
        if (k === "a" || e.key === "ArrowLeft") post("cam:rotate", { deg: -12 });
        if (k === "d" || e.key === "ArrowRight") post("cam:rotate", { deg: 12 });
        if (state.mode === "cr") {
            if (k === "w") post("cam:zoom", { dir: -1 });
            if (k === "s") post("cam:zoom", { dir: 1 });
            if (k === "e" || e.key === "ArrowUp") post("cam:lift", { dir: 1 });
            if (k === "q" || e.key === "ArrowDown") post("cam:lift", { dir: -1 });
            if (k === "z") post("cam:pan", { dir: -1 });
            if (k === "c") post("cam:pan", { dir: 1 });
        }
    });

    // ------------------------------------------------------------------
    //  SELEÇÃO
    // ------------------------------------------------------------------

    function enterSelection() {
        state.mode = "sel";
        show("#app", true);
        show("#cam", false);
        show("#tabs", false);
        show("#foot-btns", false);
        show("#btn-main", false);
        $("#tab-desc").textContent = "";
        $("#stage").classList.add("on");
        $("#crumbs").classList.add("solo");
        setHead(t("sel_eyebrow"), t("sel_title"));
        setHints([]);
    }

    function renderSelection() {
        const s = state.sel;
        $("#view-title").textContent = t("sel_subtitle");
        $("#view-count").textContent = `${s.characters.length} / ${s.slots}`;

        if (!state.selected || !s.characters.find(c => c.key === state.selected)) {
            state.selected = s.selected || (s.characters[0] && s.characters[0].key);
        }

        const view = $("#view");
        view.innerHTML = "";
        const list = el("div", "chars");

        s.characters.forEach(c => {
            const isSel = c.key === state.selected;
            const row = el("div", "char" + (isSel ? " on" : ""));

            const top = el("div", "row");
            const name = el("span", "name", `${c.firstname} ${c.lastname}`);
            if (c.isDead) name.appendChild(el("span", "dead", "✝"));
            top.appendChild(name);
            if (c.charId != null) top.appendChild(el("span", "id", `#${c.charId}`));
            row.appendChild(top);

            const sub = [];
            if (c.age != null) sub.push(`${c.age} ${t("sel_years")}`);
            sub.push(t(c.gender));
            if (c.job) sub.push(c.job);
            row.appendChild(el("div", "sub", sub.join(" · ")));

            if (isSel) {
                const more = el("div", "more");
                const kv = el("dl", "kv");
                const add = (k, v, cls) => {
                    if (v === undefined || v === null || v === "") return;
                    const d = el("div");
                    d.appendChild(el("dt", "", t(k)));
                    d.appendChild(el("dd", cls || "", v));
                    kv.appendChild(d);
                };
                add("sel_birth", fmtDate(c.birthdate));
                add("sel_nationality", c.nationality);
                add("sel_job", c.job);
                if (c.money != null) add("sel_money", fmtMoney(c.money));
                if (c.gold != null) add("sel_gold", Number(c.gold).toFixed(2), "gold");
                if (kv.children.length) more.appendChild(kv);

                const acts = el("div", "acts");
                const play = el("button", "btn", t("sel_play"));
                play.addEventListener("click", ev => { ev.stopPropagation(); playCharacter(c); });
                acts.appendChild(play);
                if (s.canRename) {
                    const ren = el("button", "btn ghost", t("sel_rename"));
                    ren.addEventListener("click", ev => { ev.stopPropagation(); renameCharacter(c); });
                    acts.appendChild(ren);
                }
                if (s.canDelete) {
                    const del = el("button", "btn ghost", t("sel_delete"));
                    del.addEventListener("click", ev => { ev.stopPropagation(); deleteCharacter(c); });
                    acts.appendChild(del);
                }
                more.appendChild(acts);
                row.appendChild(more);
            }

            row.addEventListener("click", () => {
                if (state.selected === c.key || state.busy) return;
                state.selected = c.key;
                renderSelection();
                post("sel:preview", { key: c.key });
            });
            list.appendChild(row);
        });

        for (let i = s.characters.length; i < s.slots; i++) {
            const row = el("div", "char empty");
            row.appendChild(svgUse("i-plus-c"));
            const txt = el("div");
            txt.appendChild(el("div", "name", t("sel_create")));
            txt.appendChild(el("div", "sub", t("sel_empty")));
            row.appendChild(txt);
            row.addEventListener("click", async () => {
                if (state.busy) return;
                state.busy = true;
                handleResult(await post("sel:create"));
                state.busy = false;
            });
            list.appendChild(row);
        }

        // modo Tebex: um slot bloqueado que se desbloqueia com uma compra
        if (s.tebex) {
            const row = el("div", "char locked");
            row.appendChild(svgUse("i-lock"));
            const txt = el("div");
            txt.appendChild(el("div", "name", t("tebex_slot")));
            txt.appendChild(el("div", "sub", t("tebex_slot_sub")));
            row.appendChild(txt);
            row.addEventListener("click", () => unlockSlot(s.tebex));
            list.appendChild(row);
        }
        view.appendChild(list);
    }

    function unlockSlot(tebex) {
        const body = el("div");
        body.appendChild(el("p", "", t("tebex_text")));
        if (tebex.storeUrl) body.appendChild(el("span", "store", tebex.storeUrl));
        body.appendChild(el("p", "note", t("tebex_hint")));
        const input = el("input");
        input.type = "text";
        input.placeholder = "tbx-...";
        input.style.userSelect = "text";
        body.appendChild(input);
        input.addEventListener("input", refreshModal);
        openModal({
            title: t("tebex_title"),
            body,
            okText: t("tebex_redeem"),
            canConfirm: () => /tbx-[\w-]+/i.test(input.value),
            onConfirm: async () => {
                setLoading({ text: t("tebex_checking") });
                const res = handleResult(await post("sel:tebex", { code: input.value }));
                setLoading(false);
                return !(res && res.ok);
            },
        });
    }

    async function playCharacter(c) {
        if (state.busy) return;
        state.busy = true;
        const res = handleResult(await post("sel:play", { key: c.key }));
        state.busy = false;
        if (!res || !res.ok) setLoading(false);
    }

    function deleteCharacter(c) {
        const full = `${c.firstname} ${c.lastname}`;
        const body = el("div");
        const p = el("p");
        const parts = t("del_text").split("%s");
        p.append(parts[0] || "", el("strong", "", full), parts[1] || "");
        body.appendChild(p);
        body.appendChild(el("p", "note", t("del_confirm_hint")));
        const input = el("input");
        input.type = "text";
        input.placeholder = full;
        body.appendChild(input);
        const norm = s => s.trim().replace(/\s+/g, " ").toLowerCase();
        input.addEventListener("input", refreshModal);
        openModal({
            title: t("del_title"),
            body,
            okText: t("del_confirm"),
            danger: true,
            canConfirm: () => norm(input.value) === norm(full),
            onConfirm: async () => {
                const res = handleResult(await post("sel:delete", { key: c.key, confirm: input.value }));
                return !(res && res.ok);
            },
        });
    }

    function renameCharacter(c) {
        const body = el("div", "grid2");
        const mk = (key, val) => {
            const f = el("div", "field");
            f.appendChild(el("label", "", t(key)));
            const i = el("input");
            i.type = "text";
            i.value = val;
            i.maxLength = 40;
            f.appendChild(i);
            body.appendChild(f);
            return i;
        };
        const first = mk("id_firstname", c.firstname);
        const last = mk("id_lastname", c.lastname);
        openModal({
            title: t("ren_title"),
            body,
            onConfirm: async () => {
                const res = handleResult(await post("sel:rename", { key: c.key, firstname: first.value, lastname: last.value }));
                return !(res && res.ok);
            },
        });
    }

    // ------------------------------------------------------------------
    //  CRIADOR — cabeçalho, separadores, câmara
    // ------------------------------------------------------------------

    const CAM_PRESETS = ["general", "face", "upper", "body", "lower"];
    const TAB_CAM = { identity: "general", face: "face", skin: "face", eyes: "face", hair: "upper", body: "body", makeup: "face", clothing: "general", finish: "general" };

    function renderCamRail() {
        const box = $("#cam-presets");
        box.innerHTML = "";
        CAM_PRESETS.forEach(name => {
            const b = el("button", "chip", t(`cam_${name}`));
            b.dataset.preset = name;
            b.addEventListener("click", () => { post("cam:preset", { name }); markCamPreset(name); });
            box.appendChild(b);
        });
    }

    function markCamPreset(name) {
        $("#cam-presets").querySelectorAll(".chip").forEach(b => b.classList.toggle("on", b.dataset.preset === name));
    }

    document.querySelectorAll("#cam [data-cam]").forEach(b => {
        b.addEventListener("click", () => {
            const a = b.dataset.cam;
            if (a === "rotL") post("cam:rotate", { deg: -30 });
            if (a === "rotR") post("cam:rotate", { deg: 30 });
            if (a === "zoomIn") post("cam:zoom", { dir: -1 });
            if (a === "zoomOut") post("cam:zoom", { dir: 1 });
            if (a === "up") post("cam:lift", { dir: 1 });
            if (a === "down") post("cam:lift", { dir: -1 });
            if (a === "panL") post("cam:pan", { dir: -1 });
            if (a === "panR") post("cam:pan", { dir: 1 });
            if (a === "reset") post("cam:reset");
        });
    });

    function updateTitle() {
        if (isEdit()) { $("#title").textContent = t("edit_title"); return; }
        const f = state.form;
        const name = f && `${f.firstname} ${f.lastname}`.trim();
        $("#title").textContent = name || t("cr_new");
    }

    const isEdit = () => !!(state.cr && state.cr.identity && state.cr.identity.edit);

    // Botão principal em baixo: leva ao "Finalizar" e, lá, cria a personagem
    function updateMainButton() {
        const btn = $("#btn-main");
        show("#btn-main", true);
        const onFinish = state.tab === "finish";
        let label;
        if (isEdit()) label = t("edit_save");
        else label = onFinish ? t("act_create") : t("act_finish");
        $("#btn-main-text").textContent = label;
        btn.classList.toggle("go", onFinish || isEdit());
    }

    $("#btn-main").addEventListener("click", () => {
        if (state.mode !== "cr" || state.busy) return;
        if (isEdit()) return saveEdit();
        if (state.tab !== "finish") return selectTab("finish");
        submitCharacter();
    });

    async function saveEdit() {
        state.busy = true;
        const res = handleResult(await post("cr:save", { height: state.form.height }));
        if (!res || !res.ok) setLoading(false);
        state.busy = false;
    }

    // Esconde/mostra o painel e os controlos de câmara do criador (ex.: durante o ecrã de kits)
    function showCreatorPanel(on) {
        show("#app", on);
        $("#stage").classList.toggle("on", on);
    }

    async function submitCharacter() {
        state.busy = true;
        $("#btn-main").disabled = true;
        try {
            if (!(await validateIdentity())) return;
            let kit = null;
            const kits = state.cr.identity.kits;
            if (kits && kits.list && kits.list.length) {
                kit = await chooseKit(kits);
                if (!kit) return;
            }
            const res = handleResult(await post("cr:finish", { identity: identityPayload(), spawn: state.spawn, kit }));
            if (!res || !res.ok) {
                setLoading(false);
                showCreatorPanel(true);  // o menu foi escondido para os kits; volta se algo falhar
                if (res && (ERR_FIELD[res.error] || (res.error || "").startsWith("err_name"))) await validateIdentity();
            }
        } finally {
            state.busy = false;
            $("#btn-main").disabled = false;
        }
    }

    // Ecrã de kits iniciais -> devolve o id escolhido, ou null se voltar atrás
    function chooseKit(kits) {
        return new Promise(resolve => {
            const grid = $("#kits-grid");
            grid.innerHTML = "";
            const ok = $("#kits-ok");
            ok.disabled = true;
            let picked = null;
            const img = name => {
                const i = el("img");
                i.src = (kits.imagePath || "").replace("%s", name);
                i.onerror = () => { i.style.visibility = "hidden"; };
                return i;
            };
            kits.list.forEach((kit, idx) => {
                const card = el("button", "kit");
                card.style.animationDelay = `${idx * 60}ms`;
                card.appendChild(el("span", "tick"));
                const icon = img(kit.icon || (kit.items[0] && kit.items[0].item) || "");
                icon.className = "kit-icon";
                card.appendChild(icon);
                card.appendChild(el("h3", "", kit.label));
                card.appendChild(el("p", "kit-desc", kit.description || ""));
                const ul = el("ul");
                kit.items.forEach(it => {
                    const li = el("li");
                    li.append(img(it.item), el("b", "", `${it.amount}x`), it.label || it.item);
                    ul.appendChild(li);
                });
                card.appendChild(ul);
                card.addEventListener("click", () => {
                    picked = kit.id;
                    grid.querySelectorAll(".kit").forEach(k => k.classList.toggle("on", k === card));
                    ok.disabled = false;
                });
                card.addEventListener("dblclick", () => { picked = kit.id; finish(picked); });
                grid.appendChild(card);
            });
            const finish = value => {
                show("#kits", false);
                ok.onclick = null;
                $("#kits-back").onclick = null;
                // voltar atrás => o menu de criação reaparece; escolher => continua escondido
                if (!value) showCreatorPanel(true);
                resolve(value);
            };
            ok.onclick = () => { if (picked) finish(picked); };
            $("#kits-back").onclick = () => finish(null);
            showCreatorPanel(false);
            show("#kits", true);
        });
    }

    function renderTabs() {
        const nav = $("#tabs");
        nav.innerHTML = "";
        state.cr.tabs.forEach(tab => {
            const b = el("button", "chip" + (tab.id === state.tab ? " on" : ""), tab.label);
            b.addEventListener("click", () => selectTab(tab.id));
            nav.appendChild(b);
        });
        const i = tabIndex();
        const tab = state.cr.tabs[i];
        $("#view-title").textContent = tab.label;
        $("#view-count").textContent = `${i + 1} / ${state.cr.tabs.length}`;
        $("#tab-desc").textContent = t(isEdit() && tab.id === "identity" ? "desc_edit_identity" : `desc_${tab.id}`);
        const canCancel = state.cr.identity && state.cr.identity.canCancel;
        $("#btn-prev").disabled = i === 0 && !canCancel;
        $("#btn-next").disabled = i >= state.cr.tabs.length - 1;
        updateMainButton();
    }

    function selectTab(id) {
        if (!state.cr.tabs.find(x => x.id === id)) id = "identity";
        state.tab = id;
        renderTabs();
        renderPanel(true);
        post("cr:tab", { tab: id });
        markCamPreset(TAB_CAM[id]);
    }

    function tabIndex() {
        const i = state.cr.tabs.findIndex(x => x.id === state.tab);
        return i < 0 ? 0 : i;
    }

    $("#btn-prev").addEventListener("click", () => {
        if (state.mode !== "cr") return;
        const i = tabIndex();
        if (i > 0) selectTab(state.cr.tabs[i - 1].id);
        else if (state.cr.identity && state.cr.identity.canCancel) post("cr:cancel");
    });
    $("#btn-next").addEventListener("click", () => {
        if (state.mode !== "cr") return;
        const i = tabIndex();
        if (i < state.cr.tabs.length - 1) selectTab(state.cr.tabs[i + 1].id);
    });

    $("#btn-random").addEventListener("click", async () => {
        if (state.busy) return;
        state.busy = true;
        await post("cr:random");
        state.busy = false;
    });
    $("#btn-reset").addEventListener("click", () => post("cr:reset"));

    // ------------------------------------------------------------------
    //  CRIADOR — controlos
    // ------------------------------------------------------------------

    const controlNodes = {};   // id -> { update }

    const countOf = ctl => (state.cr.counts && state.cr.counts[ctl.id]) || ctl.count || 1;

    async function sendSet(id, value) {
        const res = await post("cr:set", { id, value });
        if (res && res.patch) applyPatch(res.patch);
    }

    function applyPatch(patch) {
        Object.entries(patch).forEach(([id, p]) => {
            if (p.count !== undefined) state.cr.counts[id] = p.count;
            if (p.value !== undefined) state.cr.values[id] = p.value;
            const node = controlNodes[id];
            if (node) node.update();
        });
    }

    const NS = "http://www.w3.org/2000/svg";
    function dialSvg() {
        const svg = document.createElementNS(NS, "svg");
        svg.setAttribute("viewBox", "0 0 64 64");
        const g = document.createElementNS(NS, "g");
        g.setAttribute("class", "knob");
        const c = document.createElementNS(NS, "circle");
        c.setAttribute("class", "a"); c.setAttribute("cx", 32); c.setAttribute("cy", 32); c.setAttribute("r", 27);
        g.appendChild(c);
        for (let k = 0; k < 12; k++) {
            const l = document.createElementNS(NS, "line");
            l.setAttribute("class", "t");
            l.setAttribute("x1", 32); l.setAttribute("y1", 6.5); l.setAttribute("x2", 32); l.setAttribute("y2", 9.5);
            l.setAttribute("transform", `rotate(${k * 30} 32 32)`);
            g.appendChild(l);
        }
        const n = document.createElementNS(NS, "line");
        n.setAttribute("class", "n");
        n.setAttribute("x1", 32); n.setAttribute("y1", 4); n.setAttribute("x2", 32); n.setAttribute("y2", 10);
        g.appendChild(n);
        svg.appendChild(g);
        return { svg, knob: g };
    }

    // Opção em lista -> dial (igual às personalizações do fks-stables)
    function makeDial(ctl, label) {
        const tile = el("div", "tile");
        tile.appendChild(el("label", "", label));
        const dial = el("div", "dial");
        const { svg, knob } = dialSvg();
        const num = el("b");
        dial.append(svg, num);
        tile.appendChild(dial);

        const row = el("div", "dial-row");
        const prev = el("button", "arr"); prev.appendChild(svgUse("i-left"));
        const next = el("button", "arr"); next.appendChild(svgUse("i-right"));
        const cap = el("small");
        row.append(prev, cap, next);
        tile.appendChild(row);

        const min = () => (ctl.none ? 0 : 1);
        const get = () => {
            const v = state.cr.values[ctl.id];
            return v === undefined || v === null ? min() : Number(v);
        };
        const update = () => {
            const count = countOf(ctl);
            const v = Math.min(get(), count);
            const zero = v === 0 && ctl.none;
            knob.style.transform = `rotate(${(v / Math.max(count, 1)) * 330}deg)`;
            num.textContent = zero ? "—" : v;
            num.classList.toggle("zero", zero);
            cap.textContent = zero ? t("ctl_none") : `${v} / ${count}`;
            const locked = count <= min();
            dial.toggleAttribute("disabled", locked);
            prev.disabled = locked;
            next.disabled = locked;
        };
        const change = (v, immediate) => {
            const count = countOf(ctl);
            if (v > count) v = min();
            if (v < min()) v = count;
            if (v === get()) return;
            state.cr.values[ctl.id] = v;
            update();
            if (immediate) sendSet(ctl.id, v);
            else throttled(ctl.id, () => sendSet(ctl.id, v), 90);
        };
        prev.addEventListener("click", () => change(get() - 1, true));
        next.addEventListener("click", () => change(get() + 1, true));
        dial.addEventListener("wheel", e => { e.preventDefault(); change(get() + (e.deltaY > 0 ? 1 : -1), false); });

        // arrastar no dial: cada ~12px = 1 passo (sem dar a volta)
        dial.addEventListener("mousedown", e => {
            e.preventDefault();
            const start = { x: e.clientX, y: e.clientY, v: get() };
            dial.classList.add("drag");
            const move = ev => {
                const delta = Math.round(((ev.clientX - start.x) - (ev.clientY - start.y)) / 12);
                const count = countOf(ctl);
                const v = Math.max(min(), Math.min(count, start.v + delta));
                if (v !== get()) change(v, false);
            };
            const up = () => {
                dial.classList.remove("drag");
                window.removeEventListener("mousemove", move);
                window.removeEventListener("mouseup", up);
            };
            window.addEventListener("mousemove", move);
            window.addEventListener("mouseup", up);
        });

        controlNodes[ctl.id] = { update };
        update();
        return tile;
    }

    function paintRange(input) {
        const min = Number(input.min), max = Number(input.max), v = Number(input.value);
        const pct = ((v - min) / (max - min || 1)) * 100;
        if (min < 0) {
            input.classList.add("center");
            input.style.setProperty("--a", `${Math.min(pct, 50)}%`);
            input.style.setProperty("--b", `${Math.max(pct, 50)}%`);
        } else {
            input.style.setProperty("--p", `${pct}%`);
        }
    }

    // Valor contínuo -> barra inclinada como as estatísticas do fks-stables
    function makeStat(ctl, label) {
        const row = el("div", "stat");
        row.appendChild(el("label", "", label));
        const slider = el("input");
        slider.type = "range";
        slider.min = ctl.min;
        slider.max = ctl.max;
        slider.step = ctl.step;
        row.appendChild(slider);
        const val = el("span", "val");
        row.appendChild(val);

        const isOpacity = ctl.min === 0 && ctl.max === 1;
        const update = () => {
            const v = Number(state.cr.values[ctl.id] ?? 0);
            slider.value = v;
            paintRange(slider);
            val.textContent = isOpacity ? `${Math.round(v * 100)}%` : (v > 0 ? "+" : "") + v.toFixed(2);
            row.classList.toggle("on", v !== 0);
        };
        slider.addEventListener("input", () => {
            const v = Number(slider.value);
            state.cr.values[ctl.id] = v;
            update();
            throttled(ctl.id, () => sendSet(ctl.id, v), 60);
        });
        slider.addEventListener("dblclick", () => {
            state.cr.values[ctl.id] = 0;
            update();
            sendSet(ctl.id, 0);
        });

        controlNodes[ctl.id] = { update };
        update();
        return row;
    }

    function renderSection(view, sec) {
        if (!sec.controls || !sec.controls.length) return;
        view.appendChild(el("div", "section-label", sec.title));

        const lists = [], ranges = [];
        let prevLabel = "";
        sec.controls.forEach(ctl => {
            const label = ctl.sub && ctl.type === "range" ? prevLabel : ctl.label;
            if (!ctl.sub) prevLabel = ctl.label;
            (ctl.type === "range" ? ranges : lists).push([ctl, label]);
        });

        if (lists.length) {
            const pairs = lists.some(([c]) => c.sub);
            const grid = el("div", "dials");
            if (pairs) grid.style.gridTemplateColumns = "repeat(2, minmax(0, 1fr))";
            lists.forEach(([ctl, label]) => grid.appendChild(makeDial(ctl, label)));
            view.appendChild(grid);
        }
        if (ranges.length) {
            const box = el("div", "stats");
            ranges.forEach(([ctl, label]) => box.appendChild(makeStat(ctl, label)));
            view.appendChild(box);
        }
    }

    // ------------------------------------------------------------------
    //  CRIADOR — identidade
    // ------------------------------------------------------------------

    function defaultForm(cfg, today) {
        return {
            firstname: "", lastname: "",
            day: 1, month: 1, year: today.year - Math.max(cfg.MinAge, 25),
            height: cfg.DefaultHeight,
            nationality: "", birthplace: "", biography: "",
        };
    }

    function calcAge(f, today) {
        let age = today.year - f.year;
        if (today.month < f.month || (today.month === f.month && today.day < f.day)) age--;
        return age;
    }

    const daysIn = (m, y) => new Date(y, m, 0).getDate();

    function field(labelKey, optional, input, errKey) {
        const f = el("div", "field");
        const lab = el("label", "", t(labelKey));
        if (optional) lab.appendChild(el("small", "", ` (${t("id_optional")})`));
        f.appendChild(lab);
        f.appendChild(input);
        const err = el("div", "err");
        err.dataset.err = errKey || labelKey;
        f.appendChild(err);
        return f;
    }

    function clearErr(node) {
        const f = node.closest(".field");
        if (f) { f.classList.remove("invalid"); f.querySelector(".err").textContent = ""; }
    }

    function textInput(key, max, onInput) {
        const i = el("input");
        i.type = "text";
        i.maxLength = max;
        i.value = state.form[key] || "";
        i.addEventListener("input", () => { state.form[key] = i.value; clearErr(i); if (onInput) onInput(); });
        return i;
    }

    function renderIdentity(view) {
        if (isEdit()) return renderEditIdentity(view);
        const { cfg, today } = state.cr.identity;
        const f = state.form;

        const names = el("div", "grid2");
        names.appendChild(field("id_firstname", false, textInput("firstname", cfg.NameMaxLength, updateTitle), "first"));
        names.appendChild(field("id_lastname", false, textInput("lastname", cfg.NameMaxLength, updateTitle), "last"));
        view.appendChild(names);

        // género (fixo se foi escolhido na cutscene inicial)
        const locked = !!state.cr.identity.genderLocked;
        const sex = el("div", "sex" + (locked ? " locked" : ""));
        [["mp_male", "male", "i-male"], ["mp_female", "female", "i-female"]].forEach(([model, key, ic]) => {
            if (locked && state.cr.model !== model) return;
            const b = el("button", state.cr.model === model ? "on" : "");
            if (locked) b.disabled = true;
            b.append(svgUse(ic), t(key));
            b.addEventListener("click", async () => {
                if (state.cr.model === model || state.busy) return;
                state.busy = true;
                await post("cr:model", { model });
                state.busy = false;
            });
            sex.appendChild(b);
        });
        view.appendChild(field("id_gender", false, sex, "gender"));

        // data de nascimento
        const mkSelect = (from, to, val, key, desc) => {
            const s = el("select");
            for (let v = from; desc ? v >= to : v <= to; desc ? v-- : v++) {
                const o = el("option", "", String(v).padStart(key === "year" ? 4 : 2, "0"));
                o.value = v;
                s.appendChild(o);
            }
            s.value = val;
            s.addEventListener("change", () => {
                f[key] = Number(s.value);
                const max = daysIn(f.month, f.year);
                if (f.day > max) f.day = max;
                renderPanel(false);
            });
            return s;
        };
        const date = el("div", "grid3");
        const wrap = (labelKey, node) => { const w = el("div"); w.appendChild(el("span", "lbl", t(labelKey))); w.appendChild(node); return w; };
        date.appendChild(wrap("id_day", mkSelect(1, daysIn(f.month, f.year), f.day, "day")));
        date.appendChild(wrap("id_month", mkSelect(1, 12, f.month, "month")));
        date.appendChild(wrap("id_year", mkSelect(today.year - cfg.MinAge, today.year - cfg.MaxAge, f.year, "year", true)));
        const dateField = field("id_birthdate", false, date, "date");
        dateField.insertBefore(el("div", "age", t("id_age_preview", calcAge(f, today))), dateField.querySelector(".err"));
        view.appendChild(dateField);

        // altura
        const hRow = el("div", "height-row");
        const h = el("input");
        h.type = "range"; h.min = cfg.MinHeight; h.max = cfg.MaxHeight; h.step = 1; h.value = f.height;
        const hVal = el("b", "", `${f.height} cm`);
        paintRange(h);
        h.addEventListener("input", () => {
            f.height = Number(h.value);
            hVal.textContent = `${f.height} cm`;
            paintRange(h);
            throttled("height", () => post("cr:height", { value: f.height }), 120);
        });
        hRow.append(h, hVal);
        view.appendChild(field("id_height", false, hRow, "height"));

        const origin = el("div", "grid2");
        origin.appendChild(field("id_nationality", !cfg.RequireNationality, textInput("nationality", cfg.NationalityMaxLength), "nationality"));
        origin.appendChild(field("id_birthplace", !cfg.RequireBirthplace, textInput("birthplace", cfg.BirthplaceMaxLength), "birthplace"));
        view.appendChild(origin);

        const bio = el("textarea");
        bio.maxLength = cfg.BiographyMaxLength;
        bio.value = f.biography;
        const counter = el("div", "counter", `${f.biography.length} / ${cfg.BiographyMaxLength}`);
        bio.addEventListener("input", () => { f.biography = bio.value; counter.textContent = `${bio.value.length} / ${cfg.BiographyMaxLength}`; clearErr(bio); });
        const bioField = field("id_biography", !cfg.RequireBiography, bio, "biography");
        bioField.insertBefore(counter, bioField.querySelector(".err"));
        view.appendChild(bioField);
    }

    const ERR_FIELD = {
        err_date_invalid: "date", err_date_future: "date", err_age_min: "date", err_age_max: "date",
        err_height: "height", err_gender: "gender",
        err_nationality_required: "nationality", err_nationality_length: "nationality", err_nationality_invalid: "nationality",
        err_birthplace_required: "birthplace", err_birthplace_length: "birthplace", err_birthplace_invalid: "birthplace",
        err_biography_required: "biography", err_biography_length: "biography", err_biography_invalid: "biography",
    };

    function identityPayload() {
        const f = state.form;
        return {
            firstname: f.firstname, lastname: f.lastname,
            day: f.day, month: f.month, year: f.year,
            height: f.height, model: state.cr.model,
            nationality: f.nationality, birthplace: f.birthplace, biography: f.biography,
        };
    }

    async function validateIdentity() {
        const res = await post("cr:validate", { identity: identityPayload() });
        if (res && res.ok) return true;
        let target = res && ERR_FIELD[res.error];
        if (!target && res && res.error && res.error.startsWith("err_name")) {
            const fn = state.form.firstname.trim();
            target = "first";
            if (fn.length >= state.cr.identity.cfg.NameMinLength && /^[\p{L}][\p{L}'-]*$/u.test(fn)) target = "last";
        }
        if (state.tab !== "identity") selectTab("identity");
        setTimeout(() => {
            const err = target && document.querySelector(`.err[data-err="${target}"]`);
            if (err) {
                err.textContent = res.message || t(res.error || "err_generic");
                err.closest(".field").classList.add("invalid");
                err.scrollIntoView({ block: "center", behavior: "smooth" });
            } else {
                handleResult(res);
            }
        }, 30);
        return false;
    }

    function renderFinish(view) {
        const f = state.form;
        const { today, spawns } = state.cr.identity;
        view.appendChild(el("p", "desc", t("finish_text")));

        const kv = el("dl", "kv");
        const add = (k, v) => {
            if (!v && v !== 0) return;
            const d = el("div");
            d.appendChild(el("dt", "", t(k)));
            d.appendChild(el("dd", "", v));
            kv.appendChild(d);
        };
        add("id_firstname", f.firstname || "—");
        add("id_lastname", f.lastname || "—");
        add("id_birthdate", `${String(f.day).padStart(2, "0")}/${String(f.month).padStart(2, "0")}/${f.year}`);
        add("sel_age", `${calcAge(f, today)} ${t("sel_years")}`);
        add("id_gender", t(state.cr.model === "mp_male" ? "male" : "female"));
        add("id_height", `${f.height} cm`);
        add("id_nationality", f.nationality);
        add("id_birthplace", f.birthplace);
        view.appendChild(kv);

        if (spawns && spawns.length) {
            view.appendChild(el("div", "section-label", t("act_spawn")));
            const list = el("div", "list");
            if (state.spawn === null) state.spawn = 1;
            spawns.forEach((label, i) => {
                const b = el("button", state.spawn === i + 1 ? "on" : "", label);
                b.addEventListener("click", () => { state.spawn = i + 1; renderPanel(false); });
                list.appendChild(b);
            });
            view.appendChild(list);
        }
        // a ação de criar está no botão dourado em baixo
        view.appendChild(el("p", "desc", t("finish_hint")));
    }

    // Modo /skinmenu: só a altura é editável na identidade
    function renderEditIdentity(view) {
        const { cfg } = state.cr.identity;
        const f = state.form;
        view.appendChild(el("p", "desc", t("edit_text")));
        const hRow = el("div", "height-row");
        const h = el("input");
        h.type = "range"; h.min = cfg.MinHeight; h.max = cfg.MaxHeight; h.step = 1; h.value = f.height;
        const hVal = el("b", "", `${f.height} cm`);
        paintRange(h);
        h.addEventListener("input", () => {
            f.height = Number(h.value);
            hVal.textContent = `${f.height} cm`;
            paintRange(h);
            throttled("height", () => post("cr:height", { value: f.height }), 120);
        });
        hRow.append(h, hVal);
        view.appendChild(field("id_height", false, hRow, "height"));
    }

    function renderPanel(animate) {
        const tab = state.cr.tabs[tabIndex()];
        const view = $("#view");
        const scroll = view.dataset.tab === tab.id ? view.scrollTop : 0;
        view.innerHTML = "";
        view.dataset.tab = tab.id;
        Object.keys(controlNodes).forEach(k => delete controlNodes[k]);

        if (tab.id === "identity") renderIdentity(view);
        else if (tab.id === "finish") renderFinish(view);
        else (tab.sections || []).forEach(sec => renderSection(view, sec));

        view.scrollTop = scroll;
        if (animate) animateView();
    }

    function openCreator(data) {
        const firstOpen = !state.cr || !state.form;
        state.cr = data;
        state.cr.counts = data.counts || {};
        if (data.identity.edit) {
            // /skinmenu: sem identidade nem "Finalizar"; o botão dourado guarda
            state.cr.tabs = data.tabs.filter(tab => tab.id !== "finish");
            state.cr.tabs.forEach(tab => { if (tab.id === "identity") tab.label = t("tab_height"); });
        }
        if (firstOpen) {
            state.form = data.identity.edit
                ? { height: data.identity.height }
                : defaultForm(data.identity.cfg, data.identity.today);
            if (!data.identity.edit) state.form.height = data.identity.height || state.form.height;
            state.spawn = null;
            state.tab = data.identity.edit ? "face" : "identity";
        }
        state.mode = "cr";
        state.sel = null;
        show("#app", true);
        show("#cam", true);
        show("#tabs", true);
        show("#foot-btns", true);
        $("#stage").classList.add("on");
        $("#crumbs").classList.remove("solo");
        $("#eyebrow-text").textContent = t(data.identity.edit ? "edit_eyebrow" : "cr_eyebrow");
        updateTitle();
        setHints([["A / D", t("hint_rotate")], ["W / S", t("hint_zoom")], ["Q / E", t("hint_height")], ["Z / C", t("hint_side")]], "#cam-hints");
        renderCamRail();
        renderTabs();
        renderPanel(true);
        markCamPreset(TAB_CAM[state.tab]);
    }

    // ------------------------------------------------------------------
    //  Mensagens do Lua
    // ------------------------------------------------------------------

    window.addEventListener("message", ({ data: msg }) => {
        if (!msg || !msg.action) return;
        const d = msg.data;
        switch (msg.action) {
            case "init":
                state.locale = d.locale || {};
                translateStatic();
                break;
            case "selection":
                setLoading(false);
                closeModal();
                state.sel = d;
                state.cr = null;
                state.form = null;
                enterSelection();
                renderSelection();
                animateView();
                break;
            case "creator":
                setLoading(false);
                openCreator(d);
                break;
            case "creator:values":
                if (!state.cr) return;
                state.cr.values = d.values;
                state.cr.counts = d.counts || state.cr.counts;
                renderPanel(false);
                break;
            case "loading":
                setLoading(d);
                break;
            case "toast":
                toast(d.text, d.type);
                break;
            case "cine": {
                const card = $("#cine-card");
                if (!d.on) { show("#cine", false); card.classList.add("hidden"); break; }
                const first = $("#cine").classList.contains("hidden");
                show("#cine", true);
                if (first) {
                    const skip = $("#cine-skip");
                    skip.innerHTML = "";
                    if (d.skip !== false) { skip.appendChild(el("kbd", "", "ENTER")); skip.append(" " + t("cine_skip")); }
                }
                if (d.title) {
                    $("#cine-title").textContent = d.title;
                    $("#cine-sub").textContent = d.sub || "";
                    card.classList.remove("hidden", "out");
                } else if (!card.classList.contains("hidden")) {
                    card.classList.add("out");
                }
                break;
            }
            case "subtitle":
                if (d && d.text) {
                    $("#subtitle-text").textContent = d.text;
                    const box = $("#subtitle");
                    box.classList.add("hidden"); void box.offsetWidth; box.classList.remove("hidden");
                } else {
                    show("#subtitle", false);
                }
                break;
            case "choose":
                state.choosing = !!(d && d.on);
                show("#choose", state.choosing);
                if (state.choosing) {
                    document.querySelectorAll(".choose-opts span").forEach(s => s.classList.toggle("on", s.dataset.model === d.selected));
                }
                break;
            case "photo": {
                const on = !!(d && d.on);
                show("#photo", on);
                clearInterval(state.photoTimer);
                const count = $("#photo-count");
                count.textContent = "";
                if (on && d.seconds) {
                    let left = d.seconds;
                    const tick = () => { count.textContent = `· ${left}s`; left = Math.max(0, left - 1); };
                    tick();
                    state.photoTimer = setInterval(tick, 1000);
                }
                break;
            }
            case "close":
                setLoading(false);
                closeModal();
                show("#kits", false);
                state.mode = null;
                state.sel = null;
                state.cr = null;
                state.form = null;
                show("#app", false);
                $("#stage").classList.remove("on");
                break;
        }
    });
})();
