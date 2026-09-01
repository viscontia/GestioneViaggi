using Microsoft.AspNetCore.Components;
using System;
using System.Linq;
using Microsoft.AspNetCore.Components.Rendering;
using MudBlazor;

namespace GestioneViaggi.Components.Shared
{
    [CascadingTypeParameter(nameof(T))]
    public class EnterpriseDataGrid<T> : MudDataGrid<T>
    {
        private string _searchString = string.Empty;
        private bool _actionsColumnPinned;

        [Parameter] public string? Title { get; set; }
        [Parameter] public Func<T, string, bool>? SearchFunction { get; set; }
        [Parameter] public RenderFragment? ToolBarActions { get; set; }

        /// <summary>
        /// Rilegge i dati dalla sorgente. La griglia filtra sempre e solo cio' che ha in
        /// memoria: quando la stessa tabella la scrive anche un altro software, serve un
        /// modo esplicito per riprendere. Se non lo si passa, il pulsante non compare.
        /// </summary>
        [Parameter] public EventCallback OnRefresh { get; set; }

        public EnterpriseDataGrid()
        {
            // Default Enterprise settings - CONFIGURAZIONE CORRETTA PER CSS
            Bordered = false;
            Dense = false;      // ⚠️ IMPORTANTE: false per padding corretto
            Striped = false;    // ⚠️ IMPORTANTE: false per controllare i colori con CSS
            Hover = true;
            Elevation = 0;
            MultiSelection = false;
            ReadOnly = true;
            Class = "enterprise-grid";
            SelectOnRowClick = true;

            // Column resizing
            ColumnResizeMode = MudBlazor.ResizeMode.Container;
            HorizontalScrollbar = true;

            // Toolbar
            ToolBarContent = BuildToolbar;

            // Pager
            PagerContent = BuildPager;

            // Filter
            QuickFilter = QuickFilterFunc;
        }

        private void BuildPager(RenderTreeBuilder builder)
        {
            builder.OpenComponent<MudDataGridPager<T>>(0);
            builder.AddAttribute(1, nameof(MudDataGridPager<T>.RowsPerPageString), "Righe per pagina:");
            builder.AddAttribute(2, nameof(MudDataGridPager<T>.InfoFormat), "{first_item}-{last_item} di {all_items}");
            builder.CloseComponent();
        }

        private bool QuickFilterFunc(T item)
        {
            if (string.IsNullOrWhiteSpace(_searchString)) return true;
            if (SearchFunction != null) return SearchFunction(item, _searchString);
            return true; // If no function provided, ignore filter
        }

        private void BuildToolbar(RenderTreeBuilder builder)
        {
            builder.OpenComponent<EnterpriseGridToolbar>(0);
            builder.SetKey("EnterpriseGridToolbar");
            builder.AddAttribute(1, nameof(EnterpriseGridToolbar.Title), Title);
            builder.AddAttribute(2, nameof(EnterpriseGridToolbar.SearchString), _searchString);
            builder.AddAttribute(3, nameof(EnterpriseGridToolbar.SearchStringChanged), EventCallback.Factory.Create<string>(this, (s) =>
            {
                _searchString = s;
            }));
            builder.AddAttribute(4, nameof(EnterpriseGridToolbar.ChildContent), ToolBarActions);
            builder.AddAttribute(5, nameof(EnterpriseGridToolbar.OnRefresh), OnRefresh);
            builder.CloseComponent();
        }

        protected override void OnInitialized()
        {
            base.OnInitialized();
            // Imposta 25 righe per pagina come default (10 è il default MudBlazor).
            // Fatto qui e non nel costruttore per evitare loop di render.
            if (RowsPerPage == 10)
                RowsPerPage = 25;
        }

        protected override async Task OnAfterRenderAsync(bool firstRender)
        {
            await base.OnAfterRenderAsync(firstRender);
            EnsureActionsColumnPosition();
        }

        private void EnsureActionsColumnPosition()
        {
            if (_actionsColumnPinned) return;
            if (RenderedColumns == null || RenderedColumns.Count == 0) return;

            var actionColumns = RenderedColumns
                .Where(c => string.Equals(c.Tag?.ToString(), "Actions", StringComparison.OrdinalIgnoreCase))
                .ToList();

            if (actionColumns.Count == 0) return;

            var insertIndex = 0;

            foreach (var column in actionColumns)
            {
                var currentIndex = RenderedColumns.IndexOf(column);
                if (currentIndex == insertIndex)
                {
                    insertIndex++;
                    continue;
                }

                RenderedColumns.RemoveAt(currentIndex);
                RenderedColumns.Insert(insertIndex, column);
                insertIndex++;
            }

            _actionsColumnPinned = true;
            StateHasChanged();
        }
    }
}
