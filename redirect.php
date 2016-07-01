<?php
  //var_dump($_GET);
  //permissions = 536083519 allows us access to all (convert hexadecimal value to binary then to decimal then add)
  //bot adding link https://discordapp.com/oauth2/authorize?&client_id=169554794376200192&scope=bot+identify+email&permissions=536083519&response_type=code
  header('Content-Type: application/json');
  $totalOutput = array();
  // create curl resource
  $ch = curl_init();

  // set url
  $botAuthorizationToken = "MTY5NTU0ODgyNjc0NTU2OTMw.CfARmw.mTkahYcX0UgxNgysHmU7ATreuis";
  $code = $_GET["code"]; //not used - (wtf is this for?)
  $guildId = $_GET["guild_id"];
  $url = "https://discordapp.com/api/guilds/{$guildId}";
  //var_dump($url);
  curl_setopt($ch, CURLOPT_URL, $url);

  $headers = array();
  $headers[] = "Authorization: {$botAuthorizationToken}";
  $headers[] = "Content-Type: application/json";
  curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

  //return the transfer as a string
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);

  // $output contains the output string
  $totalOutput["guildInfo"] = json_decode(curl_exec($ch),true);
  // close curl resource to free up system resources
  curl_close($ch);

  $ch = curl_init();
  $url = "https://discordapp.com/api/guilds/{$guildId}/members?limit=100";
  //var_dump($url);
  curl_setopt($ch, CURLOPT_URL, $url);

  $headers = array();
  $headers[] = "Authorization: {$botAuthorizationToken}";
  $headers[] = "Content-Type: application/json";
  curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

  //return the transfer as a string
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);

  // $output contains the output string
  $totalOutput["members"] = json_decode(curl_exec($ch),true);
  // close curl resource to free up system resources
  curl_close($ch);

  $ch = curl_init();

  $url = "https://discordapp.com/api/users/@me";
  curl_setopt($ch, CURLOPT_URL, $url);
  curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PATCH');
  $im = file_get_contents('http://euw.lolstat.net/img/discordIcon.png');
  $imdata = base64_encode($im);
  $data = json_encode(array(
    "username" => "MotorBot",
    "avatar" => "data:image/jpeg;base64,{$imdata}"
  ));
  curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
  $headers = array();
  $headers[] = "Authorization: {$botAuthorizationToken}";
  $headers[] = "Content-Type: application/json";
  curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
  $totalOutput["editProfile"] = json_decode(curl_exec($ch),true);
  // close curl resource to free up system resources
  curl_close($ch);

  $ch = curl_init();
  $url = "https://discordapp.com/api/guilds/{$guildId}/channels";
  //var_dump($url);
  curl_setopt($ch, CURLOPT_URL, $url);

  $headers = array();
  $headers[] = "Authorization: {$botAuthorizationToken}";
  $headers[] = "Content-Type: application/json";
  curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

  //return the transfer as a string
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);

  // $output contains the output string
  $totalOutput["channels"] = json_decode(curl_exec($ch),true);
  // close curl resource to free up system resources
  curl_close($ch);


  $ch = curl_init();

  $url = "https://discordapp.com/api/guilds/{$guildId}/roles/169940799784615937";
  curl_setopt($ch, CURLOPT_URL, $url);
  curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PATCH');
  $data = json_encode(array(
    "name" => "MotorBot",
    "color" => 15105573, //convert hex with http://www.binaryhexconverter.com/hex-to-decimal-converter
    "permissions" => 66321471,
    "position" => 4,
    "hoist" => false
  ));
  curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
  $headers = array();
  $headers[] = "Authorization: {$botAuthorizationToken}";
  $headers[] = "Content-Type: application/json";
  curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
  $totalOutput["editMotorBotRoleColor"] = json_decode(curl_exec($ch),true);
  // close curl resource to free up system resources
  curl_close($ch);

  $ch = curl_init();

  $url = "https://discordapp.com/api/guilds/{$guildId}/roles/149111596277301249";
  curl_setopt($ch, CURLOPT_URL, $url);
  curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PATCH');
  $data = json_encode(array(
    "name" => "admin",
    "color" => 4057476, //convert hex with http://www.binaryhexconverter.com/hex-to-decimal-converter
    "permissions" => 66313279,
    "position" => 1,
    "hoist" => false
  ));
  curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
  $headers = array();
  $headers[] = "Authorization: {$botAuthorizationToken}";
  $headers[] = "Content-Type: application/json";
  curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
  $totalOutput["editAdminRoleColor"] = json_decode(curl_exec($ch),true);
  // close curl resource to free up system resources
  curl_close($ch);


  echo json_encode($totalOutput);
?>
