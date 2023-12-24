module calculator(switches, reset, incrementButtons, leds, displays, CLOCK);
	input [0:6] switches; // switches for each operation (can add more later)
	input reset; // leftmost switch for a reset button
	input [0:3] incrementButtons; // increment values by 1, 10, or cutom amount (add later)
	
	input CLOCK; // might not be needed
	output reg [0:9] leds; // display which mode you are using
	output reg [0:41] displays = 0; // all seven segment displays on the board
	
	reg error; // used for any error checking
	
	reg [26:0] clockCount = 0; // the value of the CLOCK
	
	reg [3:0] stage = 1; // current stage of the calculator
	/* 
		stage 1: input first number
			press leftmost push button to store the value
		stage 2: input second number 
			press leftmost push putton to store the value
		stage 3: input operator (toggle a switch on)
		stage 4: display reset and restart the program
	 */
	
	// hold a temp value of the current count
	reg [20:0] tempCount = 0;
	
	// temp value of the second input number
	reg [20:0] tempCount2 = 0;
	
	// each digit value of inputted numbers
	// 4 bit array/vector so we can use 1->9 as a digit value 
	reg [3:0] d0;
	reg [3:0] d1;
	reg [3:0] d2;
	reg [3:0] d3;
	reg [3:0] d4;
	reg [3:0] d5;
	
	// inputted numbers magnitude
	reg [20:0] num1;
	reg [20:0] num2;
	reg [20:0] answer;
	
	// An always block with a sensitivity list detecting the positive edge of the clock
	always@(posedge CLOCK)
	begin
		// Stage 1: Enter the first number
		if (stage == 1)
		begin
			// Add 1 to input number
			if (!incrementButtons[0])
			begin
				clockCount = clockCount + 1;
				if (clockCount >= 25000000)
				begin
					clockCount = 0;
					tempCount = tempCount + 1;
					getDigits(tempCount, displays);
				end
			end
			
			// Add 10 to input number
			if (!incrementButtons[1])
			begin
				clockCount = clockCount + 1;
				if (clockCount >= 25000000)
				begin
					clockCount = 0;
					tempCount = tempCount + 10;
					getDigits(tempCount, displays);
				end
			end
		end
		
		// Stage 2: Enter the second number
		if (stage == 2)
		begin
			// Add 1 to input number
			if (!incrementButtons[0])
			begin
				clockCount = clockCount + 1;
				if (clockCount >= 25000000)
				begin
					clockCount = 0;
					tempCount2 = tempCount2 + 1;
					getDigits(tempCount2, displays);
				end
			end
			
			// Add 10 to input number
			if (!incrementButtons[1])
			begin
				clockCount = clockCount + 1;
				if (clockCount >= 25000000)
				begin
					clockCount = 0;
					tempCount2 = tempCount2 + 10;
					getDigits(tempCount2, displays);
				end
			end
		end
		
		// Store an inputted value
		if (!incrementButtons[2])
		begin
			if (stage == 1)
				begin
				
					num1 = tempCount;
					
				end
			if (stage == 2)
				begin
				
					num2 = tempCount2;
	
				end
			
			clockCount = clockCount + 1;
			
			if (clockCount >= 100000000)
			begin
				
				getDigits(0, displays); // display all 0s after storing the value
				
			end
		end
		
		// // Stage 3: Select an operator to use on the two numbers using switches
		if (stage == 3)
		begin
			if (switches[0]) // addition
			begin
				add(num1, num2, answer);
				getDigits(answer, displays);
			end
			if (switches[1]) // subtraction
			begin
				subtract(num1, num2, answer);
				getDigits(answer, displays);
			end
			if (switches[2]) // multiplication
			begin
				multiply(num1, num2, answer);
				getDigits(answer, displays);
			end
			if (switches[3]) // division
			begin
				divide(num1, num2, answer);
				getDigits(answer, displays);
			end
			if (switches[4]) // exponents
			begin
				exponentiate(num1, num2, answer);
				getDigits(answer, displays);
			end
			
		end
		
		// Stage 4: Reset the values and stage
		if (stage == 4)
		begin
		
			displayReset(displays);

			tempCount = 0;
			tempCount2 = 0;
			
		end
		
	end
	
	// An always block with a sensitivity list checking for the negative edge of a button since the buttons use negative logic
	always @(negedge incrementButtons[3])
	begin
		stage <= stage + 1;
		
		// if the stage reaches 4, reset the program to stage 1 to enter new numbers
		if (stage >= 4)
		begin
			
			stage <= 1;
			
		end
		
	end
	
	// getDigits: calculate the value of each digit in a number and display them to the SSDs
	task automatic getDigits(input [19:0] currentNumber, output [0:41] out);
		begin
			// Use % to calculate each digit
			d0 = currentNumber % 10;
			currentNumber = currentNumber / 10;
			d1 = currentNumber % 10;
			currentNumber = currentNumber / 10;
			d2 = currentNumber % 10;
			currentNumber = currentNumber / 10;
			d3 = currentNumber % 10;
			currentNumber = currentNumber / 10;
			d4 = currentNumber % 10;
			currentNumber = currentNumber / 10;
			d5 = currentNumber % 10;
			
			// display each digit individually
			displayNumber(d5, out[35:41]);
			displayNumber(d4, out[28:34]); 
			displayNumber(d3, out[21:27]); 
			displayNumber(d2, out[14:20]); 
			displayNumber(d1, out[7:13]); 
			displayNumber(d0, out[0:6]);
		end
	endtask
	
	// |---------------------- ARITHMATIC OPERATIONS -----------------------|
	
	/*
	Addition: Perform addition of two numbers
	*/
	task automatic add (input [20:0] num1, num2, output [20:0] answer);
		integer magnitude1;
		integer magnitude2;
		integer sum;
		reg[19:0] sumBits;
		
		if(num1[20]) // num1 is negative
			begin
				magnitude1 = num1 [19:0]; // get the magnitude portion of num1
				magnitude1 = magnitude1 * (-1); // make it a negative integer
			end
		else
			magnitude1 = num1; // positive
			
		if(num2[20]) // num2 is negative
			begin
				magnitude2 = num2 [19:0]; // get the magnitude portion of num2
				magnitude2 = magnitude2 * (-1); // make it a negative integer
			end
		else
			magnitude2 = num2; // positive
			
		if(((magnitude1 + magnitude2) > 999999) || ((magnitude1 + magnitude2) < -999999)) //avoid overflows
			throwError(displays);
		else
			sum = magnitude1 + magnitude2; // compute the sum as an integer
		
		if(sum < 0) // if sum is negative, output the number in sign-magnitude binary form
			begin
				sum = sum * (-1); // get the positive number to store its magnitude in binary
				sumBits = sum;
				answer = {1'b1, sumBits}; // concatenate a leading 1 to indicate negative number
			end
		else
			answer = sum;
		
	endtask
	
	/*
	Subtraction: Perform subtraction of two numbers
	*/
	task automatic subtract (input [20:0] num1, num2, output [20:0] answer);
		integer magnitude1;
		integer magnitude2;
		integer difference;
		reg[19:0] differenceBits;
		
		if(num1[20]) // num1 negative
			begin
				magnitude1 = num1 [19:0]; // get magnitude
				magnitude1 = magnitude1 * (-1); // make negative integer
			end
		else
			magnitude1 = num1; // positive
			
		if(num2[20]) // num2 negative
			begin
				magnitude2 = num2 [19:0]; // get magnitude
				magnitude2 = magnitude2 * (-1); // make negative integer
			end
		else
			magnitude2 = num2;
		
    	if(((magnitude1 - magnitude2) > 999999) || ((magnitude1 - magnitude2) < -999999)) // avoid overflows
			throwError(displays);
    	else
        	difference = magnitude1 - magnitude2; //compute difference
		
		if(difference < 0) // if difference is negative, output in sign-magnitude form
			begin
				difference = difference * (-1); // get the positive number to store its magnitude in binary
				differenceBits = difference;
				answer = {1'b1, differenceBits}; // concatenate a leading 1 to indicate negative number
			end
		else
			answer = difference;
	endtask
	
	/*
	Multiplication: Perform multiplication of two numbers
	*/
	task automatic multiply (input [20:0] num1, num2, output [20:0] answer);
    	
		integer magnitude1;
		integer magnitude2;
		integer product;
		reg[19:0] productBits;
		
		if(num1[20])
			begin
				magnitude1 = num1 [19:0];
				magnitude1 = magnitude1 * (-1);
			end
		else
			magnitude1 = num1;
			
		if(num2[20])
			begin
				magnitude2 = num2 [19:0];
				magnitude2 = magnitude2 * (-1);
			end
		else
			magnitude2 = num2;
		
		if(((magnitude1 * magnitude2) > 999999) || ((magnitude1 * magnitude2) < -999999))
        	throwError(displays);
		else
			begin  
				product = magnitude1 * magnitude2;
   	   end
			
		if(product < 0)
			begin
				product = product * (-1);
				productBits = product;
				answer = {1'b1, productBits};
			end
		else
			answer = product;
	endtask
   
	/*
	Division: Perform a division of two numbers
	*/
	task automatic divide (input [20:0] num1, num2, output [20:0] answer);
    	
		integer magnitude1;
		integer magnitude2;
		integer quotient;
		reg[19:0] quotientBits;
		
		if(num1[20])
			begin
				magnitude1 = num1 [19:0];
				magnitude1 = magnitude1 * (-1);
			end
		else
			magnitude1 = num1;
			
		if(num2[20])
			begin
				magnitude2 = num2 [19:0];
				magnitude2 = magnitude2 * (-1);
			end
		else
			magnitude2 = num2;
		
		if(num2 == 0) 
			begin //avoid division by zero
				throwError(displays);
			end 
		else 
			begin
				quotient = magnitude1 / magnitude2; //integer divide
   	   end
		
		if(quotient < 0)
			begin
				quotient = quotient * (-1);
				quotientBits = quotient;
				answer = {1'b1, quotientBits};
			end
		else
			answer = quotient;
	endtask
	
	/*
	 Perform an exponentiation
		num1 is the base
		num2 is the exponent (non-negative)
	 */
	 task automatic exponentiate (input [20:0] num1, num2, output [20:0] answer);
		
		integer magnitude1;
		integer magnitude2;
		reg[19:0] resultBits;
		
		if(num1[20])
			begin
				magnitude1 = num1 [19:0];
				magnitude1 = magnitude1 * (-1);
			end
		else
			magnitude1 = num1;
			
		if(num2[20]) //if there is a negative exponent, throw an error
			begin
				throwError(displays);
			end
		else
			magnitude2 = num2;
			
		if(!error)
			begin
				if(magnitude2 > 5) //max exponent of 5
					throwError(displays);
				else
					begin
							integer a = 1;
							integer i;
							for(i = 0; i < magnitude2 && i < 6; i = i + 1) //needed to restrict iteration depth (we choose max exponent of 5), for verilog to compile
								begin
									a = a * magnitude1;
								end
							if(a > 999999 || a < -999999)
								throwError(displays);
							else
								if(a < 0) //if the answer is negative
									begin
										a = a * (-1); //get the positive magnitude
										resultBits = a;
										answer = {1'b1, resultBits}; //concatenate a 1 to indicate negative sign-magnitude binary number
									end
								else
									answer = a;
					end
				end
	endtask
	
	// |---------------------- ERROR CHECKING / DISPLAYS -----------------------|
	task automatic throwError(output [0:41] out);
		begin
			out[35:41] = 7'b0110000; // E
			out[28:34] = 7'b0011001; // r
			out[21:27] = 7'b0011001; // r
			out[14:20] = 7'b0000001; // o
			out[7:13] = 7'b0011001;  // r
			out[0:6] = 7'b1111111;   // nothing
		end
	endtask
	
	task automatic displayReset(output [0:41] out);
		begin
			out[35:41] = 7'b0011001; // r
			out[28:34] = 7'b0110000; // E
			out[21:27] = 7'b0100100; // S
			out[14:20] = 7'b0110000; // E
			out[7:13] = 7'b1110000;  // T
			out[0:6] = 7'b1111111;   // nothing
		end
	endtask
	
	/* 
	displayNumber: display each digit to the board on it's corresponding SSD
	- takes a digit as an input and outputs to the SSD passed as a parameter
	*/
	task automatic displayNumber(input [3:0] in, output [0:6] out);
		begin
			case (in)
			0:out = 7'b0000001; // 0
			1:out = 7'b1001111; // 1
			2:out = 7'b0010010; // 2
			3:out = 7'b0000110; // 3
			4:out = 7'b1001100; // 4
			5:out = 7'b0100100; // 5
			6:out = 7'b0100000; // 6
			7:out = 7'b0001111; // 7
			8:out = 7'b0000000; // 8
			9:out = 7'b0000100; // 9
			default:out = 7'b1111111; // make the default output display nothing
			endcase
		end
	
	endtask

endmodule