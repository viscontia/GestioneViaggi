using Microsoft.AspNetCore.Components;
using MudBlazor;

namespace GestioneViaggi.Components.Shared
{
    [CascadingTypeParameter(nameof(T))]
    public class EnterpriseDataGrid<T> : MudDataGrid<T>
    {
        public EnterpriseDataGrid()
        {
            // Default Enterprise settings
            Bordered = false; // We use our custom bottom border
            Dense = true;
            Striped = true;
            Hover = true;
            Elevation = 0; // Flat look inside container
            
            // Custom CSS class for styling
            Class = "enterprise-grid";
        }
    }
}
