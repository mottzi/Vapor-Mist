// Move this file (mist.js) to: /Public 

class MistSocket {

    constructor(config) {
        this.config = config;
        this.socket = null;

        this.timer = null;
        this.initialDelay = 1000;
        this.interval = 1000;

        document.addEventListener('visibilitychange', () => this.visibilityChange());
        window.addEventListener('online', () => this.connect());
        document.addEventListener('click', (event) => this.handleAction(event));
    }

    subscribeToPageComponents() {

        console.log("[Client] Scanning DOM and subscribing to components");

        const uniqueComponents = new Set();

        // Subscribe to existing components
        document.querySelectorAll('[mist-component]').forEach(element => {

            const component = element.getAttribute('mist-component');

            if (component) {
                uniqueComponents.add(component);
            }
        });

        // Subscribe to components that containers accept (even if they don't exist yet)
        document.querySelectorAll('[mist-container]').forEach(container => {

            const acceptedComponents = container.getAttribute('mist-container');

            if (acceptedComponents) {
                acceptedComponents.split(',').forEach(component => {
                    const trimmed = component.trim();
                    if (trimmed) {
                        uniqueComponents.add(trimmed);
                    }
                });
            }
        });

        uniqueComponents.forEach(component => {
            this.subscribe(component);
        });
    }

    subscribe(component) {

        if (this.isConnected()) {

            const message = {
                subscribe: {
                    component: component
                }
            };

            this.socket.send(JSON.stringify(message));
        }
    }

    // NEW: Boots global behaviors (timers, etc.)
    bootBehaviors() {
        this.bootDateTimes();
        this.bootTimers();
        this.bootInfoOverlays();
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

    bootInfoOverlays() {
        document.querySelectorAll('[mist-behavior="info-overlay"]').forEach(element => {
            if (element._mistInfoOverlay) return;

            const trigger = element.querySelector('[data-mist-overlay-trigger]');
            const panel = element.querySelector('[data-mist-overlay-panel]');

            if (!trigger || !panel) return;

            element._mistInfoOverlay = true;
            this.setInfoOverlayState(element, false);

            // Desktop: hover open/close
            element.addEventListener('mouseenter', () => {
                this.openInfoOverlay(element);
            });

            element.addEventListener('mouseleave', () => {
                this.deferInfoOverlaySync(element);
            });

            element.addEventListener('focusin', () => {
                this.openInfoOverlay(element);
            });

            element.addEventListener('focusout', () => {
                this.deferInfoOverlaySync(element);
            });

            // Touch: tap trigger to toggle, tap outside to close
            trigger.addEventListener('click', (e) => {
                e.stopPropagation();
                const isOpen = element.dataset.overlayOpen === 'true';
                // Close any other open overlays
                document.querySelectorAll('[mist-behavior="info-overlay"][data-overlay-open="true"]').forEach(other => {
                    if (other !== element) this.closeInfoOverlay(other);
                });
                if (isOpen) {
                    this.closeInfoOverlay(element);
                } else {
                    this.openInfoOverlay(element);
                }
            });

            document.addEventListener('click', (e) => {
                if (!element.contains(e.target) && element.dataset.overlayOpen === 'true') {
                    this.closeInfoOverlay(element);
                }
            });
        });
    }

    getInfoOverlayParts(element) {
        if (!(element instanceof Element)) return null;

        const trigger = element.querySelector('[data-mist-overlay-trigger]');
        const panel = element.querySelector('[data-mist-overlay-panel]');

        if (!(trigger instanceof Element) || !(panel instanceof Element)) {
            return null;
        }

        return { trigger, panel };
    }

    setInfoOverlayState(element, open) {
        const parts = this.getInfoOverlayParts(element);
        if (!parts) return;

        element.dataset.overlayOpen = open ? 'true' : 'false';
        parts.trigger.setAttribute('aria-expanded', open ? 'true' : 'false');
        parts.panel.setAttribute('aria-hidden', open ? 'false' : 'true');
    }

    openInfoOverlay(element) {
        this.setInfoOverlayState(element, true);
        this.positionInfoPopover(element);
    }

    positionInfoPopover(element) {
        const panel = element.querySelector('[data-mist-overlay-panel]');
        if (!panel) return;

        // Only apply dynamic positioning on mobile (matches CSS breakpoint)
        if (window.innerWidth > 640) {
            panel.style.top = '';
            return;
        }

        const trigger = element.querySelector('[data-mist-overlay-trigger]');
        if (!trigger) return;

        const rect = trigger.getBoundingClientRect();
        const gap = 8;
        const popoverHeight = panel.scrollHeight || 300;
        const viewportH = window.innerHeight;

        // Prefer below the trigger; if not enough room, place above
        let top = rect.bottom + gap;
        if (top + popoverHeight > viewportH - 16) {
            top = Math.max(16, rect.top - gap - popoverHeight);
        }

        panel.style.top = `${top}px`;
    }

    closeInfoOverlay(element) {
        this.setInfoOverlayState(element, false);
    }

    syncInfoOverlayState(element) {
        if (!(element instanceof Element)) return;

        if (element.matches(':hover') || element.matches(':focus-within')) {
            this.openInfoOverlay(element);
            return;
        }

        this.closeInfoOverlay(element);
    }

    deferInfoOverlaySync(element) {
        window.requestAnimationFrame(() => {
            this.syncInfoOverlayState(element);
        });
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

    handleAction(event) {

        const target = event.target.closest('[mist-action]');

        if (!target) return;

        const actionName = target.getAttribute('mist-action');

        // 1. Find component, but ID is now optional
        const componentElement = target.closest('[mist-component]');

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

            // 4. Update log message to handle null ID
            const idLog = targetID ? targetID.substring(0, 8) : 'null';
            console.log(`[Client] Action sent to server: ${componentName}.${actionName} (${idLog})`);
        }
    }

    isConnected() { return this.socket?.readyState === WebSocket.OPEN; }
    isConnecting() { return this.socket?.readyState === WebSocket.CONNECTING; }

    connect() {

        if (this.isConnected() || this.isConnecting()) return;
        if (this.socket) { this.socket.close(); this.socket = null; }

        // Use URL from config
        this.socket = new WebSocket(this.config.url);

        this.socket.onopen = () => {

            if (this.timer) { clearInterval(this.timer); this.timer = null; }

            this.subscribeToPageComponents();

            this.bootBehaviors();
        };

        this.socket.onmessage = (event) => {
            try {

                const data = JSON.parse(event.data);

                if (data.createInstanceComponent) {
                    const { component, modelID, html } = data.createInstanceComponent;

                    // Ensure the generated HTML actually belongs to the channel it was broadcasted on
                    if (!html.includes(`mist-component="${component}"`)) {
                        console.log(`[Client] Dropped cross-channel broadcast for ${component}`);
                        return;
                    }

                    const existingElements = document.querySelectorAll(this.buildComponentSelector(component, modelID));

                    // If component already exists, treat as update
                    if (existingElements.length > 0) {
                        existingElements.forEach(element => {
                            morphdom(element, html);
                        });
                        this.reorderCollectionsForElements(Array.from(existingElements));
                        console.log(`[Client] Component updated: ${component} (${modelID.substring(0, 8)})`);
                    } else {
                        // Find container that accepts this component
                        const containers = document.querySelectorAll('[mist-container]');
                        for (const container of containers) {
                            const acceptedComponents = container.getAttribute('mist-container').split(',').map(c => c.trim());
                            if (acceptedComponents.includes(component)) {
                                // Check for custom insertion position (default: 'beforeend' to append)
                                const insertPosition = container.getAttribute('mist-insert-position') || 'beforeend';
                                container.insertAdjacentHTML(insertPosition, html);
                                const insertedElements = document.querySelectorAll(this.buildComponentSelector(component, modelID));
                                this.reorderCollectionsForElements(Array.from(insertedElements));
                                console.log(`[Client] Component created: ${component} (${modelID.substring(0, 8)})`);
                                break;
                            }
                        }
                    }
                }
                else if (data.updateInstanceComponent) {
                    const { component, modelID, html } = data.updateInstanceComponent;

                    // Prevent WebSocket Crossover Updates
                    if (!html.includes(`mist-component="${component}"`)) {
                        console.log(`[Client] Dropped cross-channel update for ${component}`);
                        return;
                    }

                    const elements = document.querySelectorAll(this.buildComponentSelector(component, modelID));

                    elements.forEach(element => {
                        morphdom(element, html);
                    });
                    this.reorderCollectionsForElements(Array.from(elements));

                    console.log(`[Client] Component updated: ${component} (${modelID.substring(0, 8)})`);
                }
                else if (data.deleteInstanceComponent) {
                    const { component, modelID } = data.deleteInstanceComponent;
                    const elements = document.querySelectorAll(this.buildComponentSelector(component, modelID));

                    elements.forEach(element => {
                        element.remove();
                    });

                    console.log(`[Client] Component deleted: ${component} (${modelID.substring(0, 8)})`);
                }
                // Query-based component messages (no ID)
                else if (data.updateQueryComponent) {
                    const { component, html } = data.updateQueryComponent;
                    const existingElements = document.querySelectorAll(this.buildComponentSelector(component, null));

                    // If component already exists, replace it
                    if (existingElements.length > 0) {
                        existingElements.forEach(element => {
                            morphdom(element, html);
                        });
                        console.log(`[Client] Component updated: ${component}`);
                    } else {
                        // Find container that accepts this component
                        const containers = document.querySelectorAll('[mist-container]');

                        for (const container of containers) {
                            const acceptedComponents = container.getAttribute('mist-container').split(',').map(c => c.trim());

                            if (acceptedComponents.includes(component)) {
                                // Check for custom insertion position (default: 'beforeend' to append)
                                const insertPosition = container.getAttribute('mist-insert-position') || 'beforeend';
                                container.insertAdjacentHTML(insertPosition, html);
                                console.log(`[Client] Component created: ${component}`);
                                break;
                            }
                        }
                    }
                }
                else if (data.deleteQueryComponent) {
                    const { component } = data.deleteQueryComponent;
                    const elements = document.querySelectorAll(this.buildComponentSelector(component, null));

                    elements.forEach(element => {
                        element.remove();
                    });

                    console.log(`[Client] Component deleted: ${component}`);
                }
                else if (data.actionResult) {
                    const { component, targetID, action, result, message } = data.actionResult;
                    const isSuccess = result.success !== undefined;
                    const resultType = isSuccess ? '✅' : '❌';
                    const idLog = targetID ? targetID.substring(0, 8) : 'null';

                    console.log(`[Server] Action result ${resultType}: ${component}.${action} (${idLog}, ${message})`);
                }
                else if (data.text) {
                    const { message } = data.text;
                    console.log(`[Server] Message: ${message}`);
                }
                else {
                    console.log(`[Client] Unhandled server message (raw): ${event.data}`);
                }

                this.bootBehaviors();
            }
            catch (error) {
                console.error(`[Client] Error parsing server message: ${error}`);
            }
        };

        this.socket.onclose = () => {

            if (this.timer) return

            console.log("[Client] WebSocket closed: Reconnecting in 1s");

            setTimeout(() => {
                this.connect();

                this.timer = setInterval(() => {
                    this.connect();
                },
                this.interval);
            },
                this.initialDelay);
        };
    }

    // Helper function to build component selector
    buildComponentSelector(component, id) {
        if (id) {
            return `[mist-component="${component}"][mist-id="${id}"]`;
        } else {
            return `[mist-component="${component}"]`;
        }
    }

    visibilityChange() {
        if (document.visibilityState === "visible") {
            console.log('[Client] Document visibility changed to visible: Connecting...');
            this.connect();
        }
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
