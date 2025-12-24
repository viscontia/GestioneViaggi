// Focus helper for Enterprise Grid search field
window.focusHelper = {
    focusSearchField: function (selector) {
        // Use longer delay to ensure DOM is fully stable after all Blazor re-renders
        setTimeout(function () {
            var element = document.querySelector(selector);
            if (element) {
                element.focus();
                // Force cursor visibility by triggering a fake selection
                if (element.value !== undefined) {
                    var len = element.value.length;
                    element.setSelectionRange(len, len);
                }
            }
        }, 500); // 500ms delay to wait for all re-renders
    }
};
