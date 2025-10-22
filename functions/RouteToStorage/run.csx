#r "Newtonsoft.Json"
#r "Microsoft.Azure.Storage.Table"
#r "Azure.Storage.Blobs"

using System;
using System.IO;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json.Linq;
using Microsoft.Azure.Storage;
using Microsoft.Azure.Storage.Table;
using Azure.Storage.Blobs;

public static async Task<IActionResult> Run(string myEventHubMessage, ILogger log)
{
    log.LogInformation($"C# Event Hub trigger function processed a message: {myEventHubMessage}");

    dynamic data = JObject.Parse(myEventHubMessage);

    // Create table entity
    var callRecord = new CallRecordEntity(data.source.ToString())
    {
        RowKey = data.rowKey.ToString(),
        CallId = data.callId?.ToString(),
        StartTime = data.startTime?.ToString(),
        EndTime = data.endTime?.ToString(),
        Duration = data.duration,
        Participants = data.participants?.ToString(),
        Recording = data.recording
    };

    // Connect to Azure Table Storage
    var storageAccount = CloudStorageAccount.Parse(Environment.GetEnvironmentVariable("AzureWebJobsStorage"));
    var tableClient = storageAccount.CreateCloudTableClient();
    var table = tableClient.GetTableReference("CallRecords");

    await table.CreateIfNotExistsAsync();

    // Insert entity
    var insertOperation = TableOperation.Insert(callRecord);
    await table.ExecuteAsync(insertOperation);

    // Store raw payload in Blob Storage
    var blobServiceClient = new BlobServiceClient(Environment.GetEnvironmentVariable("AzureWebJobsStorage"));
    var containerClient = blobServiceClient.GetBlobContainerClient("call-payloads");
    await containerClient.CreateIfNotExistsAsync();

    var blobName = $"{data.source}/{DateTime.UtcNow:yyyy/MM/dd}/{data.callId}_{DateTime.UtcNow:yyyyMMdd_HHmmss}.json";
    var blobClient = containerClient.GetBlobClient(blobName);

    using var stream = new MemoryStream(Encoding.UTF8.GetBytes(myEventHubMessage));
    await blobClient.UploadAsync(stream, true);

    return new OkObjectResult("Data routed to storage successfully");
}

public class CallRecordEntity : TableEntity
{
    public CallRecordEntity(string source)
    {
        PartitionKey = source;
    }

    public string CallId { get; set; }
    public string StartTime { get; set; }
    public string EndTime { get; set; }
    public int? Duration { get; set; }
    public string Participants { get; set; }
    public bool? Recording { get; set; }
}
