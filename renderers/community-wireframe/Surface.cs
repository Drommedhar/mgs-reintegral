using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

namespace CommunityWireframe
{
    internal sealed class Surface : IDisposable
    {
        internal readonly Bitmap Image = new Bitmap(1024, 512, PixelFormat.Format32bppArgb);
        internal long Triangles { get; private set; }
        internal Rectangle View = new Rectangle(0, 0, 320, 224);
        internal bool Enabled;

        internal static Rectangle Region(byte[] body, int offset)
        {
            Wire.Require(body.Length >= offset + 16, "Missing VRAM rectangle.");
            var region = new Rectangle(Wire.I32(body, offset), Wire.I32(body, offset + 4), Wire.I32(body, offset + 8), Wire.I32(body, offset + 12));
            Wire.Require(region.X >= 0 && region.Y >= 0 && region.Width > 0 && region.Height > 0 &&
                region.Width <= 1024 - region.X && region.Height <= 512 - region.Y, "VRAM rectangle is out of range.");
            return region;
        }

        private byte[] Pixels(Rectangle region, byte[] rgba, int offset)
        {
            var locked = Image.LockBits(region, rgba == null ? ImageLockMode.ReadOnly : ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            var row = new byte[region.Width * 4];
            var result = rgba == null ? new byte[row.Length * region.Height] : rgba;
            try
            {
                for (int y = 0; y < region.Height; ++y)
                {
                    IntPtr address = IntPtr.Add(locked.Scan0, y * locked.Stride);
                    if (rgba == null) Marshal.Copy(address, row, 0, row.Length);
                    else Buffer.BlockCopy(rgba, offset + y * row.Length, row, 0, row.Length);
                    for (int x = 0; x < row.Length; x += 4)
                    {
                        byte red = row[x]; row[x] = row[x + 2]; row[x + 2] = red;
                    }
                    if (rgba == null) Buffer.BlockCopy(row, 0, result, y * row.Length, row.Length);
                    else Marshal.Copy(row, 0, address, row.Length);
                }
            }
            finally { Image.UnlockBits(locked); }
            return result;
        }

        internal byte[] Read(byte[] body)
        {
            Wire.Require(body.Length == 16, "Invalid READ size.");
            return Pixels(Region(body, 0), null, 0);
        }

        internal void Upload(byte[] body)
        {
            Rectangle region = Region(body, 0);
            Wire.Require(body.Length == 16 + region.Width * region.Height * 4, "Invalid UPLOAD size.");
            Pixels(region, body, 16);
        }

        internal void Move(byte[] body)
        {
            Wire.Require(body.Length == 24, "Invalid MOVE size.");
            Rectangle source = Region(body, 0);
            var target = new byte[16];
            Buffer.BlockCopy(body, 16, target, 0, 8);
            Buffer.BlockCopy(body, 8, target, 8, 8);
            Pixels(Region(target, 0), Pixels(source, null, 0), 0);
        }

        internal void Clear(byte[] body)
        {
            Wire.Require(body.Length == 28, "Invalid CLEAR size.");
            Rectangle region = Region(body, 0);
            int red = Wire.I32(body, 16), green = Wire.I32(body, 20), blue = Wire.I32(body, 24);
            Wire.Require((red | green | blue) >= 0 && red <= 255 && green <= 255 && blue <= 255, "Invalid CLEAR color.");
            using (var graphics = Graphics.FromImage(Image))
            using (var brush = new SolidBrush(Color.FromArgb(0, red, green, blue)))
            {
                graphics.CompositingMode = CompositingMode.SourceCopy;
                graphics.FillRectangle(brush, region);
            }
        }

        internal void Frame(byte[] body)
        {
            Wire.Require(body.Length == 28 && Wire.U32(body, 0) <= 1, "Invalid FRAME.");
            Enabled = Wire.U32(body, 0) != 0;
            if (Enabled) View = Region(body, 4);
        }

        internal void Draw(byte[] body)
        {
            Wire.Require(body.Length >= 72, "Missing DRAW header.");
            uint count = Wire.U32(body, 0), indices = Wire.U32(body, 4);
            Wire.Require(count <= 65536 && indices <= 1048576 && indices % 3 == 0 &&
                body.Length == 72L + count * 20L + indices * 2L, "Invalid DRAW lengths.");
            Rectangle clip = Region(body, 8);
            var points = new PointF[count];
            for (int index = 0; index < points.Length; ++index) points[index] = Vertex(body, index);
            using (var graphics = Graphics.FromImage(Image))
            {
                graphics.SetClip(clip);
                graphics.CompositingMode = CompositingMode.SourceCopy;
                int start = 72 + (int)count * 20;
                for (int index = 0; index < indices; index += 3)
                {
                    int a = BitConverter.ToUInt16(body, start + index * 2), b = BitConverter.ToUInt16(body, start + index * 2 + 2), c = BitConverter.ToUInt16(body, start + index * 2 + 4);
                    Wire.Require(a < count && b < count && c < count, "DRAW index exceeds vertex count.");
                    int vertex = 72 + a * 20;
                    using (var pen = new Pen(Color.FromArgb(255, body[vertex + 12], body[vertex + 13], body[vertex + 14])))
                        graphics.DrawPolygon(pen, new[] { points[a], points[b], points[c] });
                    ++Triangles;
                }
            }
        }

        private static PointF Vertex(byte[] body, int index)
        {
            int vertex = 72 + index * 20;
            bool polygon = (BitConverter.ToUInt16(body, vertex + 10) & 0x2000) != 0;
            float x = (BitConverter.ToInt16(body, vertex) + BitConverter.ToSingle(body, 24) + (polygon ? BitConverter.ToSingle(body, 32) : 0)) * BitConverter.ToSingle(body, 40) + BitConverter.ToSingle(body, 44);
            float y = BitConverter.ToInt16(body, vertex + 2) + BitConverter.ToSingle(body, 28) + (polygon ? BitConverter.ToSingle(body, 36) : 0);
            Wire.Require(!Single.IsNaN(x) && !Single.IsInfinity(x) && !Single.IsNaN(y) && !Single.IsInfinity(y) && Math.Abs(x) < 1000000 && Math.Abs(y) < 1000000, "Invalid DRAW position.");
            return new PointF(x, y);
        }

        public void Dispose() { Image.Dispose(); }
    }
}
