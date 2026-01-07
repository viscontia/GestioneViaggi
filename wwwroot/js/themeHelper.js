// Theme Helper - Force AppBar colors
window.themeHelper = {
    applyDarkMode: function(isDark) {
        const appbar = document.querySelector('.mud-appbar');
        const typography = document.querySelectorAll('.mud-appbar .mud-typography');
        const buttons = document.querySelectorAll('.mud-appbar .mud-icon-button');

        if (appbar) {
            if (isDark) {
                appbar.style.backgroundColor = '#1F2937';
                appbar.style.color = '#F9FAFB';
                appbar.style.borderBottom = '1px solid rgba(255,255,255,0.1)';
            } else {
                appbar.style.backgroundColor = '#FFFFFF';
                appbar.style.color = '#111827';
                appbar.style.borderBottom = '1px solid #e5e7eb';
            }
        }

        typography.forEach(el => {
            el.style.color = isDark ? '#F9FAFB' : '#111827';
        });

        buttons.forEach(el => {
            el.style.color = isDark ? '#F9FAFB' : '#111827';
        });
    }
};
