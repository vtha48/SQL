Câu 1: Viết các trigger sau đây (giả thiết mỗi lần bổ sung hoặc cập nhật dữ liệu chỉ tác động trên 
một dòng):
a. (1 điểm) Trigger trg_PayrollSheet_Insert bắt lệnh INSERT trên bảng PayrollSheet sao 
cho mỗi khi bổ sung một bảng lương thì tự động bổ sung danh sách các nhân viên đang làm việc vào
danh sách nhân viên được hưởng lương (bảng PayrollSheetDetails)

--1A

if exists(select * from sys.objects where name = 'trg_PayrollSheet_Insert')
    drop trigger trg_PayrollSheet_Insert;
go

create trigger trg_PayrollSheet_Insert
on PayrollSheet
for insert
as
begin
	set nocount on;
	declare @PayYear int, @PayMonth int;
	select @PayYear = PayYear, @PayMonth = PayMonth
	from inserted;

	insert into PayrollSheetDetails(PayYear, PayMonth, EmployeeId)
	select @PayYear, @PayMonth, EmployeeId
	from Employees
	where IsWorking = 1;
end
go
--test case:
insert into PayrollSheet(PayYear,PayMonth,CreatedDate, TotalOfSalary) 
values(2020,02,'2019/01/01',0);


--1b:Trigger trg_PayrollSheetDetails_Update bắt lệnh UPDATE trên bảng 
PayrollSheetDetails sao cho khi thay đổi tiền công mỗi ngày (cột SalaryPerDay) hoặc số
ngày công (cột NumberOfWorkedDays) của một dòng trong bảng này thì tính lại giá trị cột 
TotalOfSalary (tổng tiền lương của tháng) trong bảng PayrollSheet
if exists(select * from sys.objects where name = 'trg_PayrollSheetDetails_Update')
    drop trigger trg_PayrollSheetDetails_Update;
go

create trigger trg_PayrollSheetDetails_Update
on PayrollSheetDetails
for UPDATE
as
begin
	set nocount on;
	if update (SalaryPerDay) or update (NumberOfWorkedDays)
		begin
			declare @SalaryPerDay money, @NumberOfWorkedDays int;
			select @SalaryPerDay = SalaryPerDay, @NumberOfWorkedDays = NumberOfWorkedDays
			from inserted

			declare @PayYear int, @PayMonth int
			select @PayYear = PayYear, @PayMonth = PayMonth
			from inserted
			update PayrollSheet
			set TotalOfSalary = @SalaryPerDay*@NumberOfWorkedDays
			where PayYear = @PayYear and PayMonth = @PayMonth
		end
	
end
go
--test case:
update PayrollSheetDetails
set SalaryPerDay=3000, NumberOfWorkedDays=3
where EmployeeId =1


--2a:proc_PayrollSheet_Insert
@Year int,
@Month int,
2
@CreatedDate date,
@Result int output
Có chức năng bổ sung bảng lương tháng @Month năm @Year vào bảng lương (Payrollsheet). 
Tham số đầu ra @Result trả về giá trị 1 nếu bổ sung bảng lương thành công; Ngược lại, tham số
này trả về giá trị nhỏ hơn hoặc bằng 0 nhằm cho biết lý do không bổ sung được dữ liệu.

if exists( select * from sys.objects where name='proc_PayrollSheet_Insert')
	drop procedure proc_PayrollSheet_Insert;
go

create procedure proc_PayrollSheet_Insert
	@Year int,
	@Month int,
	@CreatedDate date,
	@Result int output
as
begin
	set nocount on;

	if (@Year > year(getdate())) 
		begin
			set @Result = 0;
			return;
		end

	if (@Month not between 01 and 12) 
	begin
		set @Result = -1;
		return;
	end

	if not exists ( select * from PayrollSheet where CreatedDate is null)
		return; 

	insert into PayrollSheet(PayYear,PayMonth,CreatedDate)
	values(@Year, @Month,@CreatedDate)

	set @Result =1;
end
go

--test case:
declare @r int;
execute proc_PayrollSheet_Insert
	@Year =2020,
	@Month =-10,
	@CreatedDate ='2020/10/01',
	@Result =@r output;
select @r;

--2b:proc_PayrollSheetDetails_Update
@Year int, 
@Month int, 
@EmployeeId int, 
@SalaryPerDay money, 
@NumberOfWorkedDays int
Có chức năng cập nhật giá trị tiền công mỗi ngày và số ngày công của nhân viên (bảng 
PayrollSheetDetails). Lưu ý số ngày công không được nhiều hơn số ngày của tháng.

if exists( select * from sys.objects where name='proc_PayrollSheetDetails_Update')
	drop procedure proc_PayrollSheetDetails_Update;
go

create procedure proc_PayrollSheetDetails_Update
	@Year int, 
	@Month int, 
	@EmployeeId int, 
	@SalaryPerDay money, 
	@NumberOfWorkedDays int
as
begin
	set nocount on;

	declare @NgayDauThang date , @NgayCuoiThang date, @SoNgay int
	set @NgayDauThang = DATEFROMPARTS(@Year,@Month,1);
	set @NgayCuoiThang=DATEADD(day,-1,dateadd(month,1,@NgayDauThang))
	set @SoNgay = day(@NgayCuoiThang);

	if(@NumberOfWorkedDays>@SoNgay)
		return;

	--Câu lệnh update k cần kiểm tra điều kiện dữ liệu
	update PayrollSheetDetails 
	set SalaryPerDay =@SalaryPerDay,NumberOfWorkedDays = @NumberOfWorkedDays
	where PayYear= @Year and PayMonth = @Month and  EmployeeId= @EmployeeId;

end
go

--test case: 
execute proc_PayrollSheetDetails_Update
	@Year =2020, 
	@Month =1, 
	@EmployeeId = 1, 
	@SalaryPerDay =2345, 
	@NumberOfWorkedDays=20;
select * from PayrollSheetDetails


--2c proc_ListEmployees
@SearchValue nvarchar(255) = N’’,
@Page int = 1,
@PageSize int = 20,
@RowCount int output
Có chức năng tìm kiếm và hiển thị danh sách nhân viên dưới dạng phân trang dữ liệu. Trong đó, 
@SearchValue là giá trị cần tìm (tìm kiếm tương đối theo tên nhân viên, nếu tham số này là chuỗi 
rỗng thì không tìm kiếm), @Page là trang cần hiển thị, @PageSize là số dòng dữ liệu được hiển thị
trên mỗi trang, tham số đầu ra @RowCount cho biết tổng số dòng dữ liệu.

if exists( select * from sys.objects where name='proc_ListEmployees')
	drop procedure proc_ListEmployees;
go

create procedure proc_ListEmployees
	@SearchValue nvarchar(255) = N'',
	@Page int = 1,
	@PageSize int = 20,
	@RowCount int output
as
begin
	set nocount on;

	set @SearchValue = '%' + @SearchValue +'%';
	if(@Page<1) set @Page =1;
	if(@PageSize<1) set @PageSize =20;

	select @RowCount = count(*)
	from Employees
	where EmployeeName like @SearchValue

	select  RowNumber, EmployeeName, EmployeeId
	from
		(
		select *, ROW_NUMBER()over(order by EmployeeName) as RowNumber
		from Employees
		where EmployeeName like @SearchValue
		) as t
	where t.RowNumber between (@Page -1)*@PageSize +1 and @Page*@PageSize
	order by RowNumber, EmployeeName, EmployeeId
end
go

--test case:
declare @r int;
execute proc_ListEmployees
	@SearchValue = 'A',
	@Page = 1,
	@PageSize = 20,
	@RowCount =@r output;
select @r;

--2d:proc_EmployeeSalaryByYear 
@EmployeeId int
@FromYear int
@ToYear int
Có chức năng thống kê tổng số tiền lương mà nhân viên có mã @EmployeeId nhận trong từng năm 
trong khoảng thời gian từ năm @FromYear đến năm @ToYear. Yêu cầu kết quả thống kê phải hiển 
thị đủ tất cả các năm trong khoảng thời gian trên (năm không nhận lương thì hiển thị với tổng số tiền 
lương là 0).
Lưu ý: Tiền lương tính theo công thức: SalaryPerDay * NumberOfWorkedDays

if exists( select * from sys.objects where name ='proc_EmployeeSalaryByYear')
	drop procedure proc_EmployeeSalaryByYear;
go

create procedure proc_EmployeeSalaryByYear
	@EmployeeId int,
	@FromYear int,
	@ToYear int
as
begin
	set nocount on;
	declare @tbl table
	(
	Year_ int
	)
	declare @y int
	set @y = @FromYear
	while(@y<=@ToYear)
		begin
			insert into @tbl values(@y)
			set @y +=1
		end

	select t1.Year_,t2.EmployeeId, isnull(sum(t2.TotalSalary),0) as TotalSalary
	from @tbl as t1 left join
	(
		select PayYear,EmployeeId, sum(SalaryPerDay * NumberOfWorkedDays) as TotalSalary
		from PayrollSheetDetails
		where PayYear between @FromYear and @ToYear and EmployeeId = @EmployeeId
		group by PayYear,EmployeeId
	)as t2
	on t1.Year_ = t2.PayYear
	group by t1.Year_,t2.EmployeeId
	order by t1.Year_
end
go

--test case:
exec proc_EmployeeSalaryByYear 
@EmployeeId =1,
@FromYear =2020,
@ToYear =2023


--3a func_TotalSalaryByEmployee(@EmployeeId int) có chức năng tính tổng số
tiền lương mà nhân viên có mã @EmployeeId đã nhận.

if exists( select * from sys.objects where name='func_TotalSalaryByEmployee')
	drop function func_TotalSalaryByEmployee;
go

create function func_TotalSalaryByEmployee(@EmployeeId int)
returns int
as
begin
	declare @count int
	select @count = sum(SalaryPerDay * NumberOfWorkedDays)
	from PayrollSheetDetails
	where EmployeeId = @EmployeeId
	return @count
end
go

--test case:
select dbo.func_TotalSalaryByEmployee(2)

--3b:func_GetPayrollSheet(@Year int, @Month int) có chức năng hiển thị bảng 
lương của các nhân viên trong tháng @Month năm @Year. Số liệu hiển thị bao gồm thông tin về
nhân viên, tiền công mỗi ngày, số ngày công và tiền lương được nhận

if exists( select * from sys.objects where name = 'func_GetPayrollSheet')
	drop function func_GetPayrollSheet;
go

create function func_GetPayrollSheet(@Year int, @Month int)
returns  table
as
return
(	select e.*, pd.SalaryPerDay, pd.NumberOfWorkedDays, pd.SalaryPerDay * pd.NumberOfWorkedDays as Salary
	from Employees e join PayrollSheetDetails pd on e.EmployeeId = pd.EmployeeId
	where pd.PayYear = @Year and pd.PayMonth = @Month
)

--test case:
select * from dbo.func_GetPayrollSheet(2019, 01)