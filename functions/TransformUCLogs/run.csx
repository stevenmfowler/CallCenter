#r "Newtonsoft.Json"

using System;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using Microsoft.Azure.EventHubs;

public static async Task<IActionResult> Run(string myEventHubMessage, ILogger log)
{
    log.LogInformation($"C# Event Hub trigger function processed a message: {myEventHubMessage}");

    dynamic data = JsonConvert.DeserializeObject(myEventHubMessage);

    // Transform data to unified schema
    var transformedData = new
    {
        id = Guid.NewGuid().ToString(),
        source = data.source ?? "Unknown",
        callId = data.callId ?? data.callReference ?? data.meetingId ?? data.session,
        startTime = data.startTime ?? data.timestamp ?? data.start_time,
        endTime = data.endTime,
        duration = data.duration ?? CalculateDuration(data.startTime, data.endTime),
        participants = data.participants ?? new[] { data.party?.displayName }.Where(x => x != null),
        recording = data.recording ?? false,
        partitionKey = DateTime.UtcNow.ToString("yyyyMMdd"),
        rowKey = Guid.NewGuid().ToString()
    };

    // Send transformed data to Event Hub for routing
    var eventHubClient = EventHubClient.CreateFromConnectionString(Environment.GetEnvironmentVariable("EventHubConnectionString"));
    var eventData = new EventData(Encoding.UTF8.GetBytes(JsonConvert.SerializeObject(transformedData)));
    await eventHubClient.SendAsync(eventData);

    return new OkObjectResult("Data transformed successfully");
}

private static int? CalculateDuration(dynamic startTime, dynamic endTime)
{
    if (startTime == null || endTime == null) return null;
    DateTime start = DateTime.Parse(startTime.ToString());
    DateTime end = DateTime.Parse(endTime.ToString());
    return (int)(end - start).TotalMinutes;
}
