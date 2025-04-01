({
    startPing: function() {
        const interval = 10 * 60 * 1000; // 10 minutes

        const ping = () => {
            const action = $A.get("c.ping");
            action.setCallback(this, function(response) {
                // You can add debug logs here if needed
            });
            $A.enqueueAction(action);
        };

        ping();
        window.setInterval(ping, interval);
    }
})
