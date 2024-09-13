# ga4-user-uniqueness-query
This query can be run on a GA4 export. The result of the purpose is the user-uniqueness of each dimension (inclduing custom event parameters) in the export. The metric of user-uniqueness counts the number of users (`user_pseudo_id`) that created a specific value in a specific dimension. For example, how many users have created an event where `page_location` = `https://example.com`. Based on this metric, data controllers can determine how likely a given dimension is to identify a person. 

# 🛠️ Configuration 
Before running, you will need to replace the placeholder variables:
- {{project-id}}
- {{dataset_id}}

# Output

## 🎨 Schema

|column|description|
|---|---|
|event_params_key|name of the dimension in the GA4 export. Can be a custom parameter or a default one|
|event_params_value|unique value which at least one event carried for the event_params_key|
|distinct_value_count|raw number of times that this specific event_params_value was seen for this specfiic event_params_key|
|distinct_user_count|number of user_pseudo_id that created an event carrying this event_params_value|
|rank_value_count|distinct_value_count ranked for the specific event_params_key|

## 👀 example output:
|event_params_key|event_params_value|distinct_value_count|distinct_user_count|rank_value_count|
|---|---|---|---|---|
|page_location|https://example.com|100|20|1|
|page_location|https://example.com/contact|5|5|3|
|page_location|https://example.com/product|50|10|2|

# 📊 interpretation
The idea of this query is to enable an analysis of which dimensions in the GA4 export can potentially be used as latent join keys to other databases. From here, data controllers can imagine scenarios in which those dimensions enable identification of a specific individual. If those scenarios exist, the data is likely to be personal data according to the GDPR. 
One exemplary approach would be to take the output of the query and calculate the median number of `distinct_user_count` per `event_params_key`. A median of less than 10 is highly suggestive of a dimension that is unique for most users.
