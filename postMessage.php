<?php
  header('Content-Type: application/json');
  $totalOutput = array();
  // create curl resource
  $ch = curl_init();

  // set url
  $botAuthorizationToken = "MTY5NTU0ODgyNjc0NTU2OTMw.CfARmw.mTkahYcX0UgxNgysHmU7ATreuis";
  $channelId = $_GET["channel-id"];
  $url = "https://discordapp.com/api/channels/{$channelId}/messages";

  $msg = "I also like cookies";
  if($_GET["op"] == 1){
    $msg = "\nLatest jQuery Library:\n\n```HTML\n<script src=\"http://code.jquery.com/jquery-latest.min.js\" type=\"text/javascript\"></script>\n```";
  }
  else if($_GET["op"] == 2){
    $msg = "My new status is **{$_GET['string']}**";
  }
  else if($_GET["op"] == 3){
    $msg = "{$_GET['msg']}";
  }
  else if($_GET["op"] == 4){
    $msg = "You can find me at: \n ```JSON\nhttps://discordapp.com/oauth2/authorize?&client_id=169554794376200192&scope=bot+identify+email&permissions=66321471&response_type=code\n```";
  }
  else if($_GET["op"] == 5){
    $lolstatURL = "http://api.lolstat.net/AppData/profileHeader/euw/".urlencode(strtolower(str_replace(" ","",$_GET['summoner'])));
    $ch2 = curl_init();
    //var_dump($url);
    curl_setopt($ch2, CURLOPT_URL, $lolstatURL);
    //return the transfer as a string
    curl_setopt($ch2, CURLOPT_RETURNTRANSFER, 1);

    // $output contains the output string
    $output = json_decode(curl_exec($ch2),true);
    // close curl resource to free up system resources
    curl_close($ch2);
    $summonerInfo = reset($output);
    $jsonData = json_encode($output);
    $msg = "*LoLStat API Request Init*\n\n> Getting Summoner Data for **{$_GET['summoner']}** in region **EUW**\n> {$lolstatURL}\n> Complete\n\n```JSON\n{$jsonData}\n```";
  }

  if($_GET["op"] == 5 || $_GET["op"] == 4 || $_GET["op"] == 3 || $_GET["op"] == 2 || $_GET["op"] == 1){
    $fields = array(
      "content" => urlencode("{$msg}"),
      "tts" => "false"
    );
  }
  else{
    $fields = array(
      "content" => urlencode("<@{$_GET["author"]}> {$msg}"),
      "tts" => "false"
    );
  }

  $fields_string = "content={$fields["content"]}&nonce={$fields["nonce"]}&tts={$fields["tts"]}";
  curl_setopt($ch, CURLOPT_URL, $url);

  $headers = array();
  $headers[] = "Authorization: {$botAuthorizationToken}";
  curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
  curl_setopt($ch, CURLOPT_POST, count($fields));
  curl_setopt($ch, CURLOPT_POSTFIELDS, $fields_string);

  //return the transfer as a string
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);

  // $output contains the output string
  $totalOutput[] = json_decode(curl_exec($ch),true);
  // close curl resource to free up system resources
  curl_close($ch);

  echo json_encode($totalOutput);
?>
