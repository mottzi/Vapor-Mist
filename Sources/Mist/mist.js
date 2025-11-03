// Move this file (mist.js) to: /Public 

class MistSocket
{
    constructor()
    {
        // websocket
        this.socket = null;
        
        // reconnect
        this.timer = null;
        this.initialDelay = 1000;
        this.interval = 5000;
        
        document.addEventListener('visibilitychange', () => this.visibilityChange());
        window.addEventListener('online', () => this.connect());
    }
    
    subscribeToPageComponents()
    {
        console.log("subscribing to server components...");
        
        // Collect unique component types using a Set
        const uniqueComponents = new Set();
        
        // Find all elements with mist-component attribute
        document.querySelectorAll('[mist-component]').forEach(element =>
        {
            const component = element.getAttribute('mist-component');
            
            if (component)
            {
                uniqueComponents.add(component);
            }
        });
        
        // Subscribe to each unique component type exactly once
        uniqueComponents.forEach(component =>
        {
            this.subscribe(component);
        });
    }
    
    subscribe(component)
    {
        if (this.isConnected())
        {
            const message =
            {
                subscribe: {
                    component: component
                }
            };
            
            this.socket.send(JSON.stringify(message));
        }
    }
    
    unsubscribe(component)
    {
        if (this.isConnected())
        {
            const message =
            {
                unsubscribe: {
                    component: component
                }
            };
            
            this.socket.send(JSON.stringify(message));
        }
    }
    
    isConnected() { return this.socket?.readyState === WebSocket.OPEN; }
    isConnecting() { return this.socket?.readyState === WebSocket.CONNECTING; }
    
    connect()
    {
        // abort if already connected or currently connecting
        if (this.isConnected() || this.isConnecting()) return;
        
        // close existing socket
        if (this.socket) { this.socket.close(); this.socket = null; }
        
        // create new socket and try to connect
        this.socket = new WebSocket('wss://mottzi.de/mist/ws/');
        
        // connected: stop existing reconnect timer
        this.socket.onopen = () =>
        {
            if (this.timer) { clearInterval(this.timer); this.timer = null; }
            
            // subscribe to components after ws connection is established
            this.subscribeToPageComponents();
        };
        
        // parse incoming messages
        this.socket.onmessage = (event) =>
        {
            try
            {
                console.log(`RAW: ${event.data}`);
                const data = JSON.parse(event.data);
                
                if (data.update)
                {
                    const { component, id, html } = data.update;
                    const elements = document.querySelectorAll(`[mist-component="${component}"][mist-id="${id}"]`);
                    
                    elements.forEach(element =>
                    {
                        element.outerHTML = html;
                    });
                }
            }
            catch (error)
            {
                console.error(`WS: Failed to parse message: ${error}`);
            }
        };
        
        // disconnected: start reconnect timer
        this.socket.onclose = () =>
        {
            // abort if a reconnect timer is already running
            if (this.timer) return
                
                console.log("WS: ... closed -> Connect in 1s ...");
            
            // start trying every 5s
            setTimeout(() =>
            {
                this.connect();
                
                this.timer = setInterval(() =>
                {
                    this.connect();
                },
                this.interval);
            },
            this.initialDelay);
        };
    }
    
    visibilityChange()
    {
        if (document.visibilityState === "visible")
        {
            console.log('visibilityState === "visible" -> calling connect()')
            this.connect();
        }
    }
}

// Wait for the DOM to be fully loaded before executing the code
document.addEventListener('DOMContentLoaded', function ()
{
    window.ws = new MistSocket();
    window.ws.connect()
});
