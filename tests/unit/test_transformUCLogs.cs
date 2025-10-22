using System;
using Xunit;
using Moq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace CallCenterPlatform.Tests.Unit
{
    public class TransformUCLogsTests
    {
        [Fact]
        public async Task TransformUCLogs_TransformsDataCorrectly_WhenValidInputProvided()
        {
            // Arrange
            var loggerMock = new Mock<ILogger>();
            var function = new TransformUCLogs();
            var inputMessage = @"{
                ""source"": ""Teams"",
                ""callId"": ""CALL_001"",
                ""startTime"": ""2023-10-01T10:00:00Z"",
                ""endTime"": ""2023-10-01T10:30:00Z"",
                ""participants"": [""user1@domain.com"", ""user2@domain.com""],
                ""recording"": true
            }";

            // Act
            var result = await function.Run(inputMessage, loggerMock.Object);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            Assert.Equal("Data transformed successfully", okResult.Value);

            // Additional assertions would verify Event Hub publishing
            // This would require mocking the EventHubClient
        }

        [Fact]
        public void CalculateDuration_ReturnsCorrectDuration_WhenStartAndEndTimesProvided()
        {
            // Arrange
            var startTime = "2023-10-01T10:00:00Z";
            var endTime = "2023-10-01T10:30:00Z";

            // Act
            var duration = TransformUCLogs.CalculateDuration(startTime, endTime);

            // Assert
            Assert.Equal(30, duration);
        }

        [Fact]
        public void CalculateDuration_ReturnsNull_WhenStartOrEndTimeMissing()
        {
            // Arrange
            string startTime = null;
            var endTime = "2023-10-01T10:30:00Z";

            // Act
            var duration = TransformUCLogs.CalculateDuration(startTime, endTime);

            // Assert
            Assert.Null(duration);
        }
    }
}
