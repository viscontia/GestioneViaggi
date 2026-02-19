window.triggerDownload = (fileName, url) => {
    const anchorElement = document.createElement('a');
    anchorElement.href = url;
    anchorElement.download = fileName ?? '';
    anchorElement.click();
    anchorElement.remove();
};

// Scroll MudSelect dropdown to selected item
window.scrollToSelectedMudSelectItem = () => {
    setTimeout(() => {
        // MudSelect uses MudPopover with a mud-list inside
        // The selected item has class 'mud-selected' on the mud-list-item
        const popover = document.querySelector('.mud-popover-open');
        if (!popover) {
            return;
        }

        // Find the scrollable container (mud-list inside the popover)
        const scrollContainer = popover.querySelector('.mud-list');
        if (!scrollContainer) {
            return;
        }

        // Find the selected item - MudBlazor adds 'mud-selected' class
        const selectedItem = scrollContainer.querySelector('.mud-selected');
        if (!selectedItem) {
            return;
        }

        // Calculate scroll position to center the selected item
        const containerHeight = scrollContainer.clientHeight;
        const itemTop = selectedItem.offsetTop;
        const itemHeight = selectedItem.offsetHeight;
        const scrollPosition = itemTop - (containerHeight / 2) + (itemHeight / 2);
        
        scrollContainer.scrollTop = Math.max(0, scrollPosition);
    }, 80);
};

// Helper function for responsive breakpoint detection
// Returns the current window inner width in pixels
// Used by MainLayout for responsive drawer variant selection
window.getWindowWidth = () => window.innerWidth;
