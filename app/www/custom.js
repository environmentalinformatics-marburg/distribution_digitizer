$(document).ready(function() {
  $('#title').hover(function() {
    $('#title_infoBox').css("display", "block");  // Zeigt die Info-Box
  }, function() {
    $('#title_infoBox').css("display", "none");   // Versteckt die Info-Box
  });
  $('#pYear').hover(function() {
    $('#pYear_infoBox').css("display", "block");  // Zeigt die Info-Box
  }, function() {
    $('#pYear_infoBox').css("display", "none");   // Versteckt die Info-Box
  });
  
  $('#author').hover(function() {
    $('#author_infoBox').css("display", "block");  // Zeigt die Info-Box
  }, function() {
    $('#author_infoBox').css("display", "none");   // Versteckt die Info-Box
  });
  
  $('#tesserAct').hover(function() {
    $('#tesserAct_infoBox').css("display", "block");  // Zeigt die Info-Box
  }, function() {
    $('#tesserAct_infoBox').css("display", "none");   // Versteckt die Info-Box
  });
  $('#dataInputDir').hover(function() {
    $('#dataInputDir_infoBox').css("display", "block");  // Zeigt die Info-Box
  }, function() {
    $('#dataInputDir_infoBox').css("display", "none");   // Versteckt die Info-Box
  });

  $('#dataOutputDir').hover(function() {
    $('#dataOutputDir_infoBox').css("display", "block");  // Zeigt die Info-Box
  }, function() {
    $('#dataOutputDir_infoBox').css("display", "none");   // Versteckt die Info-Box
  });
  
  $('#d_pColor').hover(function() {
    $('#pColor_infoBox').css("display", "block");  // Zeigt die Info-Box
  }, function() {
    $('#pColor_infoBox').css("display", "none");   // Versteckt die Info-Box
  });
  
  $('#d_pFormat').hover(function() {
    $('#pFormat_infoBox').css("display", "block");  // Zeigt die Info-Box
  }, function() {
    $('#pFormat_infoBox').css("display", "none");   // Versteckt die Info-Box
  });
});


