using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace LanHub
{
    public class NetworkManagementService
    {
        public IEnumerable<object> GetInterfaces()
        {
            return NetworkInterface.GetAllNetworkInterfaces()
                .Select(ni => new
                {
                    Name = ni.Name,
                    Description = ni.Description,
                    Type = ni.NetworkInterfaceType.ToString(),
                    Status = ni.OperationalStatus.ToString(),
                    SpeedMbps = ni.Speed / 1_000_000,
                    MacAddress = FormatMac(ni.GetPhysicalAddress()),
                    IPv4 = ni.GetIPProperties().UnicastAddresses
                        .Where(u => u.Address.AddressFamily == AddressFamily.InterNetwork)
                        .Select(u => u.Address.ToString())
                        .ToList(),
                    IPv6 = ni.GetIPProperties().UnicastAddresses
                        .Where(u => u.Address.AddressFamily == AddressFamily.InterNetworkV6)
                        .Select(u => u.Address.ToString())
                        .ToList(),
                    Statistics = new {
                        BytesSent = ni.GetIPv4Statistics().BytesSent,
                        BytesReceived = ni.GetIPv4Statistics().BytesReceived
                    }
                });
        }

        public IEnumerable<object> GetTcpConnections()
        {
            var props = IPGlobalProperties.GetIPGlobalProperties();
            return props.GetActiveTcpConnections()
                .Select(c => new
                {
                    LocalAddress = c.LocalEndPoint.Address.ToString(),
                    LocalPort = c.LocalEndPoint.Port,
                    RemoteAddress = c.RemoteEndPoint.Address.ToString(),
                    RemotePort = c.RemoteEndPoint.Port,
                    State = c.State.ToString()
                });
        }

        public IEnumerable<object> GetTrafficSummary()
        {
            return NetworkInterface.GetAllNetworkInterfaces()
                .Where(ni => ni.OperationalStatus == OperationalStatus.Up)
                .Select(ni => new
                {
                    Name = ni.Name,
                    BytesReceived = ni.GetIPv4Statistics().BytesReceived,
                    BytesSent = ni.GetIPv4Statistics().BytesSent,
                    PacketsReceived = ni.GetIPv4Statistics().UnicastPacketsReceived,
                    PacketsSent = ni.GetIPv4Statistics().UnicastPacketsSent
                });
        }

        public async Task<IEnumerable<object>> CapturePacketsAsync(int durationSeconds)
        {
            var summary = new Dictionary<string, int>();
            int seconds = Math.Clamp(durationSeconds, 1, 60);

            using var socket = new Socket(AddressFamily.InterNetwork, SocketType.Raw, ProtocolType.IP);
            socket.Bind(new IPEndPoint(IPAddress.Any, 0));
            socket.IOControl(IOControlCode.ReceiveAll, BitConverter.GetBytes(1), null);

            var buffer = new byte[65535];
            var endTime = DateTime.UtcNow.AddSeconds(seconds);
            while (DateTime.UtcNow < endTime)
            {
                if (socket.Poll(1000, SelectMode.SelectRead))
                {
                    int received = socket.Receive(buffer);
                    if (received > 0)
                    {
                        ProtocolType protocol = (ProtocolType)buffer[9];
                        string key = protocol.ToString();
                        summary[key] = summary.ContainsKey(key) ? summary[key] + 1 : 1;
                    }
                }
            }

            return summary.Select(kvp => new { Protocol = kvp.Key, Count = kvp.Value });
        }

        private static string FormatMac(PhysicalAddress address)
        {
            if (address == null || address.Equals(PhysicalAddress.None))
                return string.Empty;
            return string.Join(":", address.GetAddressBytes().Select(b => b.ToString("X2")));
        }
    }
}
