namespace GestioneViaggi.Models.DTOs
{
    public class AnnoBilancioDTO
    {
        public int Anno { get; set; }
        public int NumeroViaggi { get; set; }

        public override string ToString()
        {
            return $"{Anno} (Numero viaggi: {NumeroViaggi})";
        }
    }
}
