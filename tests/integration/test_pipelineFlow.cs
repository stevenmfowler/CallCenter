using System;
using Xunit;
using Moq;
using System.Threading.Tasks;
using System.Net.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Azure.EventHubs;

namespace CallCenterPlatform.Tests.Integration
{
    public class PipelineFlowTests : IDisposable
    {
        private readonly Mock<IEventHubClient> _eventHubMock;
        private readonly Mock<ILogger> _loggerMock;

        public PipelineFlowTests()
        {
            _eventHubMock = new Mock<IEventHubClient>();
            _loggerMock = new Mock<ILogger>();
        }

        [Fact]
        public async Task PipelineFlow_ProcessesDataEndToEnd_WhenValidInputProvided()
        {
            // Arrange
            var ingestFunction = new IngestTeamsCalls();
            var transformFunction = new TransformUCLogs();
            var routeFunction = new RouteToStorage();

            var inputJson = @"{
                ""source"": ""Teams"",
                ""callId"": ""CALL_001"",
                ""startTime"": ""2023-10-01T10:00:00Z"",
                ""endTime"": ""2023-10-01T10:30:00Z"",
                ""participants"": [""user1@domain.com"", ""user2@domain.com""],
                ""recording"": true
            }";

            // Simulate ingestion
            var ingestResult = await ingestFunction.Run(CreateHttpRequest(inputJson), _loggerMock.Object);
            Assert.IsType<OkObjectResult>(ingestResult);

            // Simulate transformation
            var transformResult = await transformFunction.Run(inputJson, _loggerMock.Object);
            Assert.IsType<OkObjectResult>(transformResult);

            // Simulate routing
            var routeResult = await routeFunction.Run(inputJson, _loggerMock.Object);
            Assert.IsType<OkObjectResult>(routeResult);
        }

        [Fact]
        public async Task PipelineFlow_HandlesDifferentSourcesCorrectly()
        {
            // Test with different source systems
            var sources = new[] { "Teams", "Avaya", "Zoom", "Ringcentral" };

            foreach (var source in sources)
            {
                var inputJson = $@"{{
                    ""source"": ""{source}"",
                    ""callId"": ""{source}_001"",
                    ""startTime"": ""2023-10-01T10:00:00Z"",
                    ""endTime"": ""2023-10-01T10:30:00Z"",
                    ""participants"": [""user1@domain.com""],
                    ""recording"": false
                }}";

                var routeFunction = new RouteToStorage();
                var result = await routeFunction.Run(inputJson, _loggerMock.Object);

                Assert.IsType<OkObjectResult>(result);
            }
        }

        private HttpRequest CreateHttpRequest(string json)
        {
            var request = new DefaultHttpContext().Request;
            request.Body = new MemoryStream(Encoding.UTF8.GetBytes(json));
            request.ContentType = "application/json";
            return request;
        }

        public void Dispose()
        {
            // Cleanup code if needed
        }
    }
}
