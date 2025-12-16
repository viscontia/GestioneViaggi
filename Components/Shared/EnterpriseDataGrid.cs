using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Rendering;
using MudBlazor;

namespace GestioneViaggi.Components.Shared
{
    [CascadingTypeParameter(nameof(T))]
    public class EnterpriseDataGrid<T> : MudDataGrid<T>
    {
        private string _searchString = string.Empty;

        [Parameter] public string? Title { get; set; }
        [Parameter] public Func<T, string, bool>? SearchFunction { get; set; }

        public EnterpriseDataGrid()
        {
            // Default Enterprise settings
            Bordered = false;
            Dense = true;
            Striped = true;
            Hover = true;
            Elevation = 0;
            MultiSelection = false;
            ReadOnly = true;
            Class = "enterprise-grid";

            // Toolbar
            ToolBarContent = BuildToolbar;
            
            // Filter
            QuickFilter = QuickFilterFunc;
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
            builder.AddAttribute(1, nameof(EnterpriseGridToolbar.Title), Title);
            builder.AddAttribute(2, nameof(EnterpriseGridToolbar.SearchString), _searchString);
            builder.AddAttribute(3, nameof(EnterpriseGridToolbar.SearchStringChanged), EventCallback.Factory.Create<string>(this, (s) => 
            { 
                _searchString = s; 
                StateHasChanged(); 
            }));
            builder.CloseComponent();
        }
    }
}
