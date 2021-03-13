window.addEventListener('DOMContentLoaded', (event) => {
	if( window.innerWidth >= 1200 ){
		var content = document.querySelectorAll('.work-images .col-');
		//or however you get a handle to the IMG
		content.forEach(function(col){
			var img = col.querySelector('img');
			if(img){
				img.addEventListener('load', (event) => {
					var ratio = img.naturalHeight / img.naturalWidth;
					if(ratio >= 1){
						col.classList.add("col-6");
					}
				});
			}
			var vid = col.querySelector('video');
			if(vid){
				vid.addEventListener('loadeddata', (event) => {
					if(vid.readyState >= 1) {
						var ratio = vid.videoHeight / vid.videoWidth;
						if(ratio >= 1){
							col.classList.add("col-6");
						}
					}
				});
			}
			var div = col.querySelector('.ratio');
			if(div){
				var style = window.getComputedStyle(div);
				var ratio = style.getPropertyValue('--bs-aspect-ratio');
				if(parseFloat(ratio) / 100.0 >= 1){
					col.classList.add("col-6");
				}
			}
		});
	}
});