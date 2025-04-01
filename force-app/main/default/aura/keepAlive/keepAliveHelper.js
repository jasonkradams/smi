({
    startPing: function(component) {
        const interval = 10 * 60 * 1000;

        const ping = () => {
            console.log('[KeepAlive] Pinging server to keep session alive…');

            const action = component.get("c.ping");
            action.setCallback(this, function(response) {
                const state = response.getState();
                if (state === "SUCCESS") {
                    console.log('[KeepAlive] Ping response: SUCCESS');
                } else {
                    const errors = response.getError();
                    console.error('[KeepAlive] Ping response: ERROR', errors);
                }
            });
            $A.enqueueAction(action);
        };

        ping();
        window.setInterval(ping, interval);
    }
})
