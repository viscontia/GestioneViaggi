using MudBlazor;
using Microsoft.Extensions.Localization;

namespace GestioneViaggi.Components.Shared
{
    public class ItalianMudLocalizer : MudLocalizer
    {
        private Dictionary<string, string> _localization;

        public ItalianMudLocalizer()
        {
            _localization = new Dictionary<string, string>
            {
                // Filtri
                { "MudDataGrid.is equals", "è uguale a" },
                { "MudDataGrid.is not equals", "non è uguale a" },
                { "MudDataGrid.contains", "contiene" },
                { "MudDataGrid.not contains", "non contiene" },
                { "MudDataGrid.starts with", "inizia con" },
                { "MudDataGrid.ends with", "finisce con" },
                { "MudDataGrid.is empty", "è vuoto" },
                { "MudDataGrid.is not empty", "non è vuoto" },
                
                // Bottoni e Label Generiche
                { "MudDataGrid.Filter", "Filtro" },
                { "MudDataGrid.Unsort", "Rimuovi ordinamento" },
                { "MudDataGrid.Sort", "Ordina" },
                { "MudDataGrid.Columns", "Colonne" },
                { "MudDataGrid.HideAll", "Nascondi tutto" },
                { "MudDataGrid.ShowAll", "Mostra tutto" },
                { "MudDataGrid.Group", "Raggruppa" },
                { "MudDataGrid.Ungroup", "Separa" },
                { "MudDataGrid.MoveUp", "Sposta su" },
                { "MudDataGrid.MoveDown", "Sposta giù" },
                { "MudDataGrid.Refresh", "Aggiorna" },
                { "MudDataGrid.Save", "Salva" },
                { "MudDataGrid.Cancel", "Annulla" },
                
                // Paginazione
                { "MudDataGridPager.RowsPerPage", "Righe per pagina:" },
                { "MudDataGrid.RowsPerPage", "Righe per pagina:" }, // Variante
                { "RowsPerPage", "Righe per pagina:" }, // Variante semplice

                { "MudDataGridPager.InfoFormat", "{first_item}-{last_item} di {all_items}" },
                { "MudDataGrid.InfoFormat", "{first_item}-{last_item} di {all_items}" }, // Variante
            };
        }

        public override LocalizedString this[string key]
        {
            get
            {
                if (_localization.TryGetValue(key, out var res))
                {
                    return new LocalizedString(key, res);
                }
                return base[key];
            }
        }
    }
}
