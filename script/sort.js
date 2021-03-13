document.addEventListener("DOMContentLoaded", function() {
	var cards = document.querySelectorAll('.col-');
    Array.prototype.slice.call(cards).sort(function sort (ca, cb) {
        var a = ca.querySelector('.year').textContent.trim();
        var b = cb.querySelector('.year').textContent.trim();
        if (a > b){
        	return -1;
        }
        else if(a < b){
        	 return 1;
        }
        else{
        	return 0;
        }
    }).forEach(function(div) {
        div.parentElement.appendChild(div);
    });
});
