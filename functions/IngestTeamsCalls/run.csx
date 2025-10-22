#r "Newtonsoft.Json"

using System;
using System.Net;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Primitives;
using Newtonsoft.Json;
using Microsoft.Azure.EventHubs;

public static async Task<IActionResult> Run(HttpRequest req, ILogger log)
{
    log.LogInformation("C# HTTP trigger function processed a request.");

    string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
    dynamic data = JsonConvert.DeserializeObject(requestBody);

    // Process Teams call data
    // Send to Event Hub
    var eventHubClient = EventHubClient.CreateFromConnectionString(Environment.GetEnvironmentVariable("EventHubConnectionString"));

    var eventData = new EventData(Encoding.UTF8.GetBytes(requestBody));
    await eventHubClient.SendAsync(eventData);

    return new OkObjectResult("Teams call data ingested successfully");
}
