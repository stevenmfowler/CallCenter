using System;
using Xunit;
using Moq;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace CallCenterPlatform.Tests.Unit
{
    public class IngestTeamsCallsTests
    {
        [Fact]
        public async Task IngestTeamsCalls_ReturnsSuccess_WhenValidDataProvided()
        {
            // Arrange
            var loggerMock = new Mock<ILogger>();
            var function = new IngestTeamsCalls();

            // Act
            var result = await function.Run(CreateHttpRequest(), loggerMock.Object);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            Assert.Equal("Teams call data ingested successfully", okResult.Value);
        }

        private HttpRequest CreateHttpRequest()
        {
            var json = @"{
                ""callId"": ""CALL_001"",
                ""startTime"": ""2023-10-01T10:00:00Z"",
                ""endTime"": ""2023-10-01T10:30:00Z"",
                ""participants"": [""user1@domain.com"", ""user2@domain.com""],
                ""recording"": true
            }";

            var request = new DefaultHttpContext().Request;
            request.Body = new MemoryStream(Encoding.UTF8.GetBytes(json));
            request.ContentType = "application/json";

            return request;
        }
    }
}
