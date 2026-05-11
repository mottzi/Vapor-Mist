// Move this file (mist.js) to: /Public

class MistSocket {

    constructor(config) {
        this.config = config;
        this.socket = null;
        this.streamBuffers = new Map();
        this.throttledUpdates = new Map();

        // Reconnect
        this.reconnectTimer = null;
        this.reconnectDelay = 1000;

        // Heartbeat
        this.heartbeatTimer        = null;
        this.heartbeatInterval     = 30_000;
        this.heartbeatTimeoutTimer = null;
        this.heartbeatTimeout      = 10_000;
        this.pendingHeartbeat      = false;
        this.hasConnectedOnce = false;

        document.addEventListener('visibilitychange', () => this.visibilityChange());
        window.addEventListener('online', () => this.forceReconnect());
        document.addEventListener('click', (event) => this.handleAction(event));
    }

    forceReconnect() {
        if (this.socket) {
            // Null all handlers before close so onclose doesn't schedule a competing reconnect loop
            this.socket.onclose   = null;
            this.socket.onerror   = null;
            this.socket.onopen    = null;
            this.socket.onmessage = null;
            this.socket.close();
            this.socket = null;
        }
        this.stopHeartbeat();
        this.clearReconnectTimer();
        this.connect();
    }

    startHeartbeat() {
        this.stopHeartbeat();
        this.heartbeatTimer = setInterval(() => this.sendHeartbeat(), this.heartbeatInterval);
    }

    stopHeartbeat() {
        clearInterval(this.heartbeatTimer);
        clearTimeout(this.heartbeatTimeoutTimer);
        this.heartbeatTimer        = null;
        this.heartbeatTimeoutTimer = null;
        this.pendingHeartbeat      = false;
    }

    sendHeartbeat() {
        if (!this.isConnected()) return;

        if (this.pendingHeartbeat) {
            console.warn('[Client] Heartbeat timeout — connection is dead, forcing reconnect');
            this.forceReconnect();
            return;
        }

        this.pendingHeartbeat = true;
        this.socket.send(JSON.stringify({ ping: {} }));

        this.heartbeatTimeoutTimer = setTimeout(() => {
            if (this.pendingHeartbeat) {
                console.warn('[Client] Heartbeat pong not received — forcing reconnect');
                this.forceReconnect();
            }
        }, this.heartbeatTimeout);
    }

    handlePong() {
        const wasPending = this.pendingHeartbeat;
        this.pendingHeartbeat = false;

        if (this.heartbeatTimeoutTimer) {
            clearTimeout(this.heartbeatTimeoutTimer);
            this.heartbeatTimeoutTimer = null;
        }

        // If a pong arrives and the heartbeat interval is not running, 
        // it means we just successfully verified the connection after a wake-up.
        if (wasPending && !this.heartbeatTimer && this.isConnected()) {
            console.log('[Client] Connection verified — resuming heartbeats');
            this.startHeartbeat();
        }
    }

    clearReconnectTimer() {
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }
    }

    subscribeToPageComponents() {

        console.log("[Client] Scanning DOM and subscribing to components");

        const uniqueComponents = new Map();

        // Subscribe to existing components
        document.querySelectorAll('[mist-component]').forEach(element => {

            const component = element.getAttribute('mist-component');
            const ssrReady = !this.hasConnectedOnce && element.getAttribute('mist-ssr') === 'true';

            if (component) {
                uniqueComponents.set(component, ssrReady);
            }
        });

        // Subscribe to components that containers accept (even if they don't exist yet)
        document.querySelectorAll('[mist-container]').forEach(container => {

            const acceptedComponents = container.getAttribute('mist-container');
            const ssrReady = !this.hasConnectedOnce && container.getAttribute('mist-ssr') === 'true';

            if (acceptedComponents) {
                acceptedComponents.split(',').forEach(component => {
                    const trimmed = component.trim();
                    if (trimmed && (!uniqueComponents.has(trimmed) || (!uniqueComponents.get(trimmed) && ssrReady))) {
                        uniqueComponents.set(trimmed, ssrReady);
                    }
                });
            }
        });

        uniqueComponents.forEach((ssrReady, component) => {
            this.subscribe(component, ssrReady);
        });
    }

    subscribe(component, ssrReady = false) {

        if (this.isConnected()) {

            const message = {
                subscribe: {
                    component: component,
                    ssrReady: ssrReady
                }
            };

            this.socket.send(JSON.stringify(message));
        }
    }

    // Boots global behaviors (timers, etc.)
    bootBehaviors() {
        this.bootDateTimes();
        this.bootTimers();
    }

    bootDateTimes() {
        const timeFormatter = new Intl.DateTimeFormat(undefined, {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
            hour12: false
        });
        const dateFormatter = new Intl.DateTimeFormat(undefined, {
            day: '2-digit',
            month: '2-digit',
            year: '2-digit'
        });

        document.querySelectorAll('[mist-behavior="local-datetime"]').forEach(element => {
            const unixMs = Number.parseInt(element.dataset.startedAtUnixMs, 10);
            if (Number.isNaN(unixMs)) return;

            const date = new Date(unixMs);
            const timeElement = element.querySelector('.dp-time-value');
            const dateElement = element.querySelector('.dp-time-date');

            if (timeElement) {
                timeElement.textContent = timeFormatter.format(date);
            }

            if (dateElement) {
                dateElement.textContent = dateFormatter.format(date);
            }
        });
    }

    bootTimers() {
        document.querySelectorAll('[mist-behavior="timer"]').forEach(element => {
            if (element._mistTimer) return;
            const unixMs = Number.parseInt(element.dataset.startedAtUnixMs, 10);
            if (Number.isNaN(unixMs)) return;

            const update = () => {
                const elapsed = Math.max((Date.now() - unixMs) / 1000, 0);
                element.textContent = `${elapsed.toFixed(1)}s`;
            };

            update();

            element._mistTimer = setInterval(() => {
                // Stop if element is removed from DOM
                if (!document.body.contains(element)) {
                    clearInterval(element._mistTimer);
                    element._mistTimer = null;
                    return;
                }

                // Stop if element no longer has the timer behavior (e.g. morphed into static span)
                if (element.getAttribute('mist-behavior') !== 'timer') {
                    clearInterval(element._mistTimer);
                    element._mistTimer = null;
                    return;
                }

                update();
            }, 100);
        });
    }

    applyThrottledUpdate(key, delayMs, applyFn, data) {
        let record = this.throttledUpdates.get(key);

        if (record) {
            record.pendingData = data;
            return false;
        }

        applyFn(data);

        record = {
            pendingData: null,
            timer: setTimeout(() => {
                const r = this.throttledUpdates.get(key);
                this.throttledUpdates.delete(key);
                if (r && r.pendingData !== null) {
                    this.applyThrottledUpdate(key, delayMs, applyFn, r.pendingData);
                }
            }, delayMs)
        };
        this.throttledUpdates.set(key, record);
        return true;
    }

    streamKey(component, modelID, stream) {
        return `${component}\u0000${modelID}\u0000${stream}`;
    }

    rememberStream(component, modelID, stream, text) {
        const key = this.streamKey(component, modelID, stream);
        this.streamBuffers.set(key, { component, modelID, stream, text });
        return key;
    }

    replaceStream(component, modelID, stream, text) {
        this.rememberStream(component, modelID, stream, text);
        this.setStreamText(component, modelID, stream, text);
    }

    appendStream(component, modelID, stream, text) {
        if (!text) return;

        const key = this.streamKey(component, modelID, stream);
        const existing = this.streamBuffers.get(key);
        const nextText = (existing?.text || '') + text;
        this.streamBuffers.set(key, { component, modelID, stream, text: nextText });

        this.findStreamTargets(component, modelID, stream).forEach(target => {
            target.appendChild(document.createTextNode(text));
            this.scrollStreamTargetToBottom(target);
        });
    }

    closeStream(component, modelID, stream) {
        this.streamBuffers.delete(this.streamKey(component, modelID, stream));
    }

    restoreStreams() {
        this.streamBuffers.forEach(({ component, modelID, stream, text }) => {
            this.setStreamText(component, modelID, stream, text);
        });
    }

    setStreamText(component, modelID, stream, text) {
        this.findStreamTargets(component, modelID, stream).forEach(target => {
            target.textContent = text;
            this.scrollStreamTargetToBottom(target);
        });
    }

    findStreamTargets(component, modelID, stream) {
        const selector = `${this.buildComponentSelector(component, modelID)} [mist-stream="${this.escapeAttributeValue(stream)}"]`;
        return Array.from(document.querySelectorAll(selector));
    }

    scrollStreamTargetToBottom(target) {
        if (!(target instanceof HTMLElement)) return;
        if (target.offsetParent === null && target.getClientRects().length === 0) return;
        target.scrollTop = target.scrollHeight;
    }

    parseSortValue(rawValue, sortType) {
        if (rawValue === null || rawValue === undefined || rawValue === '') {
            return null;
        }

        if (sortType === 'number') {
            const numericValue = Number.parseFloat(rawValue);
            return Number.isNaN(numericValue) ? null : numericValue;
        }

        return rawValue;
    }

    findSortableCollection(element) {
        if (!(element instanceof Element)) return null;
        return element.closest('[mist-behavior="sortable-collection"]');
    }

    scheduleSortableCollectionReorder(collection) {
        if (!(collection instanceof Element)) return;

        const delayRawValue = collection.dataset.mistSortDelayMs;
        const parsedDelay = Number.parseInt(delayRawValue ?? '0', 10);
        const delayMs = Number.isNaN(parsedDelay) ? 0 : Math.max(parsedDelay, 0);

        if (collection._mistSortTimer) {
            clearTimeout(collection._mistSortTimer);
            collection._mistSortTimer = null;
        }

        if (delayMs === 0) {
            this.reorderSortableCollection(collection);
            return;
        }

        collection._mistSortTimer = setTimeout(() => {
            collection._mistSortTimer = null;
            this.reorderSortableCollection(collection);
        }, delayMs);
    }

    reorderSortableCollection(collection) {
        if (!(collection instanceof Element)) return;

        const sortOrder = collection.dataset.mistSortOrder || 'asc';
        const sortType = collection.dataset.mistSortType || 'number';
        const sortableItems = Array.from(collection.children).filter(child =>
            child.hasAttribute('data-mist-sort-value')
        );

        if (sortableItems.length < 2) return;

        const indexedItems = sortableItems.map((element, index) => ({
            element,
            index,
            value: this.parseSortValue(element.getAttribute('data-mist-sort-value'), sortType)
        }));

        const sortedItems = [...indexedItems].sort((left, right) => {
            if (left.value === null && right.value === null) return left.index - right.index;
            if (left.value === null) return 1;
            if (right.value === null) return -1;

            if (left.value === right.value) return left.index - right.index;

            if (sortOrder === 'desc') {
                return left.value > right.value ? -1 : 1;
            }

            return left.value < right.value ? -1 : 1;
        });

        const orderChanged = sortedItems.some((item, index) => item.element !== sortableItems[index]);
        if (!orderChanged) return;

        // Preserve the positions of non-sortable siblings while reordering only sortable ones.
        const markers = sortableItems.map(element => {
            const marker = document.createComment('mist-sort-slot');
            collection.insertBefore(marker, element);
            return marker;
        });

        sortedItems.forEach((item, index) => {
            collection.insertBefore(item.element, markers[index]);
            markers[index].remove();
        });
    }

    reorderCollectionsForElements(elements) {
        const collections = new Set();

        elements.forEach(element => {
            const collection = this.findSortableCollection(element);
            if (collection) {
                collections.add(collection);
            }
        });

        collections.forEach(collection => this.scheduleSortableCollectionReorder(collection));
    }

    htmlBelongsToComponent(html, component) {
        return html.includes(`mist-component="${component}"`);
    }

    findComponentElements(component, modelID = null) {
        return Array.from(document.querySelectorAll(this.buildComponentSelector(component, modelID)));
    }

    morphComponentElements(elements, html) {
        elements.forEach(element => {
            morphdom(element, html);
        });
    }

    insertIntoAcceptedContainer(component, html) {
        const containers = document.querySelectorAll('[mist-container]');

        for (const container of containers) {
            const acceptedComponents = container.getAttribute('mist-container').split(',').map(c => c.trim());

            if (acceptedComponents.includes(component)) {
                const insertPosition = container.getAttribute('mist-insert-position') || 'beforeend';
                container.insertAdjacentHTML(insertPosition, html);
                return true;
            }
        }

        return false;
    }

    applyInstanceHTML(component, modelID, html, insertIfMissing = false) {
        const elements = this.findComponentElements(component, modelID);

        if (elements.length > 0) {
            const delay = elements[0].getAttribute('mist-delay');
            if (delay) {
                const delayMs = parseInt(delay, 10);
                if (!isNaN(delayMs) && delayMs > 0) {
                    const key = `instance:${component}:${modelID}`;
                    const applied = this.applyThrottledUpdate(key, delayMs, (latestHTML) => {
                        const currentElements = this.findComponentElements(component, modelID);
                        if (currentElements.length > 0) {
                            this.morphComponentElements(currentElements, latestHTML);
                            this.reorderCollectionsForElements(currentElements);
                            this.restoreStreams();
                            this.bootBehaviors();
                            console.log(`[Client] Component updated: ${component} (${this.shortID(modelID)})`);
                        }
                    }, html);
                    return applied ? 'updated' : null;
                }
            }
            this.morphComponentElements(elements, html);
            this.reorderCollectionsForElements(elements);
            return 'updated';
        }

        if (insertIfMissing && this.insertIntoAcceptedContainer(component, html)) {
            const insertedElements = this.findComponentElements(component, modelID);
            this.reorderCollectionsForElements(insertedElements);
            return 'created';
        }

        return null;
    }

    applyQueryHTML(component, html) {
        const elements = this.findComponentElements(component, null);

        if (elements.length > 0) {
            const delay = elements[0].getAttribute('mist-delay');
            if (delay) {
                const delayMs = parseInt(delay, 10);
                if (!isNaN(delayMs) && delayMs > 0) {
                    const key = `query:${component}`;
                    const applied = this.applyThrottledUpdate(key, delayMs, (latestHTML) => {
                        const currentElements = this.findComponentElements(component, null);
                        if (currentElements.length > 0) {
                            this.morphComponentElements(currentElements, latestHTML);
                            this.restoreStreams();
                            this.bootBehaviors();
                            console.log(`[Client] Component updated: ${component}`);
                        }
                    }, html);
                    return applied ? 'updated' : null;
                }
            }
            this.morphComponentElements(elements, html);
            return 'updated';
        }

        if (this.insertIntoAcceptedContainer(component, html)) {
            return 'created';
        }

        return null;
    }

    removeComponentElements(component, modelID = null) {
        const elements = this.findComponentElements(component, modelID);

        elements.forEach(element => {
            element.remove();
        });

        return elements;
    }

    handleAction(event) {

        const target = event.target.closest('[mist-action]');

        if (!target) return;

        const actionName = target.getAttribute('mist-action');

        // 1. Find component: ancestor with [mist-component], or [mist-actions-for="Name"] for detached controls
        let componentElement = target.closest('[mist-component]');
        if (!componentElement && target.hasAttribute('mist-actions-for')) {
            const ref = target.getAttribute('mist-actions-for');
            if (ref) {
                const safe = ref.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
                componentElement = document.querySelector('[mist-component="' + safe + '"]');
            }
        }

        if (!componentElement || !actionName) return;

        const componentName = componentElement.getAttribute('mist-component');
        // 2. ID can now be null, which is valid
        const targetID = componentElement.getAttribute('mist-id');

        // 3. Only require componentName. targetID is optional.
        if (!componentName) return;

        if (this.isConnected()) {

            const message = {
                action: {
                    component: componentName,
                    targetID: targetID, // Will correctly send `targetID: null` if not found
                    action: actionName
                }
            };

            this.socket.send(JSON.stringify(message));

            console.log(`[Client] Action sent to server: ${componentName}.${actionName} (${this.shortID(targetID)})`);
        }
    }

    isConnected() { return this.socket?.readyState === WebSocket.OPEN; }
    isConnecting() { return this.socket?.readyState === WebSocket.CONNECTING; }

    connect() {
        if (this.isConnected() || this.isConnecting()) return;
        if (this.socket) { this.socket.close(); this.socket = null; }

        this.socket = new WebSocket(this.config.url);

        this.socket.onopen = () => {
            this.clearReconnectTimer();
            this.startHeartbeat();
            this.subscribeToPageComponents();
            this.bootBehaviors();
            this.hasConnectedOnce = true;
            console.log('[Client] WebSocket connected');
        };

        this.socket.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);

                if (data.pong) {
                    this.handlePong();
                    return;
                }

                const mutatedHTML = this.applyServerMessage(data, event.data);
                if (mutatedHTML === null) return;
                this.afterServerMessageApplied(mutatedHTML);
            }
            catch (error) {
                console.error(`[Client] Error parsing server message: ${error}`);
            }
        };

        this.socket.onerror = (error) => {
            console.error('[Client] WebSocket error:', error);
            // onclose always fires after onerror — reconnect logic lives there
        };

        this.socket.onclose = (event) => {
            this.stopHeartbeat();
            this.clearReconnectTimer();
            console.log(`[Client] WebSocket closed (code ${event.code}) — reconnecting in ${this.reconnectDelay}ms`);
            this.reconnectTimer = setTimeout(() => {
                this.reconnectTimer = null;
                this.connect();
            }, this.reconnectDelay);
        };
    }

    applyServerMessage(data, rawMessage) {
        if (data.pong) return false;   // handled in onmessage; defensive guard only
        if (data.createInstanceComponent) return this.applyInstanceCreateMessage(data.createInstanceComponent);
        if (data.updateInstanceComponent) return this.applyInstanceUpdateMessage(data.updateInstanceComponent);
        if (data.deleteInstanceComponent) return this.applyInstanceDeleteMessage(data.deleteInstanceComponent);
        if (data.updateQueryComponent) return this.applyQueryUpdateMessage(data.updateQueryComponent);
        if (data.deleteQueryComponent) return this.applyQueryDeleteMessage(data.deleteQueryComponent);
        if (data.replaceStream) return this.applyStreamReplaceMessage(data.replaceStream);
        if (data.appendStream) return this.applyStreamAppendMessage(data.appendStream);
        if (data.closeStream) return this.applyStreamCloseMessage(data.closeStream);
        if (data.actionResult) return this.applyActionResultMessage(data.actionResult);
        if (data.text) return this.applyTextMessage(data.text);

        console.log(`[Client] Unhandled server message (raw): ${rawMessage}`);
        return false;
    }

    applyInstanceCreateMessage(message) {
        const { component, modelID, html } = message;

        if (!this.htmlBelongsToComponent(html, component)) {
            console.log(`[Client] Dropped cross-channel broadcast for ${component}`);
            return null;
        }

        const result = this.applyInstanceHTML(component, modelID, html, true);
        if (result === 'updated') {
            console.log(`[Client] Component updated: ${component} (${this.shortID(modelID)})`);
        } else if (result === 'created') {
            console.log(`[Client] Component created: ${component} (${this.shortID(modelID)})`);
        }

        return !!result;
    }

    applyInstanceUpdateMessage(message) {
        const { component, modelID, html } = message;

        if (!this.htmlBelongsToComponent(html, component)) {
            console.log(`[Client] Dropped cross-channel update for ${component}`);
            return null;
        }

        const result = this.applyInstanceHTML(component, modelID, html);
        if (result === 'updated') {
            console.log(`[Client] Component updated: ${component} (${this.shortID(modelID)})`);
        }

        return !!result;
    }

    applyInstanceDeleteMessage(message) {
        const { component, modelID } = message;
        this.removeComponentElements(component, modelID);
        console.log(`[Client] Component deleted: ${component} (${this.shortID(modelID)})`);
        return false;
    }

    applyQueryUpdateMessage(message) {
        const { component, html } = message;
        const result = this.applyQueryHTML(component, html);

        if (result === 'updated') {
            console.log(`[Client] Component updated: ${component}`);
        } else if (result === 'created') {
            console.log(`[Client] Component created: ${component}`);
        }

        return !!result;
    }

    applyQueryDeleteMessage(message) {
        const { component } = message;
        this.removeComponentElements(component, null);
        console.log(`[Client] Component deleted: ${component}`);
        return false;
    }

    applyStreamReplaceMessage(message) {
        const { component, modelID, stream, text } = message;
        this.replaceStream(component, modelID, stream, text);
        console.log(`[Client] Stream replaced: ${component}.${stream} (${this.shortID(modelID)})`);
        return false;
    }

    applyStreamAppendMessage(message) {
        const { component, modelID, stream, text } = message;
        this.appendStream(component, modelID, stream, text);
        console.log(`[Client] Stream appended: ${component}.${stream} (${this.shortID(modelID)})`);
        return false;
    }

    applyStreamCloseMessage(message) {
        const { component, modelID, stream } = message;
        this.closeStream(component, modelID, stream);
        console.log(`[Client] Stream closed: ${component}.${stream} (${this.shortID(modelID)})`);
        return false;
    }

    applyActionResultMessage(message) {
        const { component, targetID, action, result, message: textMessage } = message;
        const isSuccess = result.success !== undefined;
        const resultType = isSuccess ? '✅' : '❌';
        console.log(`[Server] Action result ${resultType}: ${component}.${action} (${this.shortID(targetID)}, ${textMessage})`);
        return false;
    }

    applyTextMessage(message) {
        console.log(`[Server] Message: ${message.message}`);
        return false;
    }

    afterServerMessageApplied(mutatedHTML) {
        if (mutatedHTML) {
            this.restoreStreams();
        }
        this.bootBehaviors();
    }

    shortID(id) {
        return id ? id.substring(0, 8) : 'null';
    }

    // Helper function to build component selector
    buildComponentSelector(component, id) {
        const safeComponent = this.escapeAttributeValue(component);
        if (id) {
            return `[mist-component="${safeComponent}"][mist-id="${this.escapeAttributeValue(id)}"]`;
        } else {
            return `[mist-component="${safeComponent}"]`;
        }
    }

    escapeAttributeValue(value) {
        return String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    }

    visibilityChange() {
        if (document.visibilityState === 'visible') {
            if (this.isConnected()) {
                this.verifyConnection();
            } else {
                console.log('[Client] Page became visible — socket not open, forcing reconnect');
                this.forceReconnect();
            }
        } else {
            // Stop heartbeat while hidden — background timers are throttled and cause false-positive pong timeouts
            this.stopHeartbeat();
        }
    }

    verifyConnection() {
        console.log('[Client] Page became visible — verifying connection...');

        // Stop any existing heartbeat interval/timeout before the check
        this.stopHeartbeat();

        this.pendingHeartbeat = true;
        this.socket.send(JSON.stringify({ ping: {} }));

        // Use a short timeout for the wake-up check to detect zombie sockets quickly
        const wakeUpTimeout = 1500;

        this.heartbeatTimeoutTimer = setTimeout(() => {
            if (this.pendingHeartbeat) {
                console.warn('[Client] Wake-up pong not received — forcing reconnect');
                this.forceReconnect();
            }
        }, wakeUpTimeout);
    }
}

// Capture the script element immediately to read attributes
const mistScript = document.currentScript;

// Wait for the DOM to be fully loaded before executing the code
document.addEventListener('DOMContentLoaded', function () {
    let path = '/mist/ws/'; // Default path

    if (mistScript) {
        const dataUrl = mistScript.getAttribute('data-url');
        if (dataUrl) {
            path = dataUrl;
        }
    }

    // Construct full URL
    const protocol = window.location.protocol === 'https:' ? 'wss://' : 'ws://';
    const host = window.location.host;
    const url = `${protocol}${host}${path}`;

    window.ws = new MistSocket({ url: url });
    window.ws.bootBehaviors();
    window.ws.connect();
});
