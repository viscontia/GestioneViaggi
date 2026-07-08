namespace GestioneViaggi.Services.Shared.Geo;

/// <summary>
/// Decimazione traccia con l'algoritmo Douglas-Peucker (implementato a mano, no NetTopologySuite).
/// Iterativo (stack) per evitare stack overflow su tracce lunghe (migliaia di punti).
/// Aumenta la tolleranza finché il numero di punti scende sotto <c>maxPoints</c> (cap per il
/// limite di lunghezza dell'URL Geoapify). Distanza planare: ok su aree piccole (un tour).
/// </summary>
public static class DouglasPeucker
{
    public static List<GeoPoint> Simplify(IReadOnlyList<GeoPoint> points, int maxPoints = 280, double startEps = 0.00005)
    {
        if (points.Count <= maxPoints) return points.ToList();

        var eps = startEps;
        var result = Reduce(points, eps);
        var guard = 0;
        while (result.Count > maxPoints && guard++ < 100)
        {
            eps *= 1.4;
            result = Reduce(points, eps);
        }
        return result;
    }

    private static List<GeoPoint> Reduce(IReadOnlyList<GeoPoint> pts, double eps)
    {
        var n = pts.Count;
        if (n < 3) return pts.ToList();

        var keep = new bool[n];
        keep[0] = keep[n - 1] = true;

        var stack = new Stack<(int First, int Last)>();
        stack.Push((0, n - 1));
        while (stack.Count > 0)
        {
            var (first, last) = stack.Pop();
            double dmax = 0;
            int index = 0;
            for (int i = first + 1; i < last; i++)
            {
                var d = PerpDistance(pts[i], pts[first], pts[last]);
                if (d > dmax) { dmax = d; index = i; }
            }
            if (dmax > eps && index > first)
            {
                keep[index] = true;
                stack.Push((first, index));
                stack.Push((index, last));
            }
        }

        var res = new List<GeoPoint>(n);
        for (int i = 0; i < n; i++)
            if (keep[i]) res.Add(pts[i]);
        return res;
    }

    private static double PerpDistance(GeoPoint p, GeoPoint a, GeoPoint b)
    {
        double dx = b.Lat - a.Lat, dy = b.Lon - a.Lon;
        if (dx == 0 && dy == 0)
            return Math.Sqrt((p.Lat - a.Lat) * (p.Lat - a.Lat) + (p.Lon - a.Lon) * (p.Lon - a.Lon));
        var num = Math.Abs(dy * p.Lat - dx * p.Lon + b.Lat * a.Lon - b.Lon * a.Lat);
        return num / Math.Sqrt(dx * dx + dy * dy);
    }
}
